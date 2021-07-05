package com.example.flutter_piano_audio_detection;

import org.tensorflow.lite.Interpreter;

import android.content.Context;
import android.content.res.AssetFileDescriptor;

import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.MediaRecorder;
import android.os.Handler;
import android.os.Looper;
import android.os.Process;
import android.util.Log;

import androidx.annotation.NonNull;

import java.io.FileInputStream;
import java.io.IOException;
import java.nio.MappedByteBuffer;
import java.nio.channels.FileChannel;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.locks.ReentrantLock;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/** FlutterPianoAudioDetectionPlugin */
public class FlutterPianoAudioDetectionPlugin implements FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
  // flutter
  private HashMap arguments;
  private EventChannel.EventSink events;
  private Result result;

  private MethodChannel channel;
  private EventChannel eventChannel;

  private Context context;
  private Handler handler = new Handler(Looper.getMainLooper());
  private String LOG_TAG = "FLUTTER_PITCH_TRACKER";
  private String MODEL_FILENAME = "onsets_frames_wavinput.tflite"; //Google Magenta Tflite Model File

  AudioRecord record = null;
  private int SAMPLE_RATE = 16000;
  private int RECORDING_LENGTH = 17920;
  private long MINIMUM_TIME_BETWEEN_SAMPLES_MS = 30;

  //Working variables.
  boolean lastInferenceRun = false;
  private short[] recordingBuffer = new short[RECORDING_LENGTH];
  private int recordingOffset = 0;
  boolean shouldContinue = true;
  boolean shouldContinueRecognition = true;
  private long lastProcessingTimeMs;

  private Thread recordingThread = null;
  private Thread recognitionThread = null;
  private Runnable recordingRunnable = null;
  private Runnable recognitionRunnable = null;

  private ReentrantLock recordingBufferLock = new ReentrantLock();

  private Interpreter tfLite = null;


  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "flutter_piano_audio_detection");
    eventChannel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), "startAudioRecognition");

    channel.setMethodCallHandler(this);
    eventChannel.setStreamHandler(this);

    this.context = flutterPluginBinding.getApplicationContext();
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
    eventChannel.setStreamHandler(null);
  }

  @Override
  public void onListen(Object arguments, EventChannel.EventSink events) {
    this.events = events;
    this.arguments = (HashMap)arguments;
  }

  @Override
  public void onCancel(Object arguments) {
    this.events = null;
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    this.arguments = (HashMap) call.arguments;
    this.result = result;
    switch (call.method){
      case "prepare":
        loadModel();
        break;
      case "start":
        startRecord();
        startRecognition();
        break;
      case "stop":
        stopRecording();
        stopRecognition();
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  private void loadModel() {
    Log.v(LOG_TAG, "Audio Engine Prepare");
    try {
      tfLite = new Interpreter(loadModelFile(context, MODEL_FILENAME));
      Log.v(LOG_TAG, "Tflite Model Successfully Loaded");
      result.success(true);
    }
    catch (Exception e) {
      Log.v(LOG_TAG, "Can Not Tflite Model Load");
      result.success(false);
      e.printStackTrace();
    }
    tfLite.resizeInput(0, new int[RECORDING_LENGTH]);
  }

  private MappedByteBuffer loadModelFile(Context context, String modelPath) throws IOException {
    AssetFileDescriptor fileDescriptor = context.getAssets().openFd(modelPath);
    FileInputStream inputStream = new FileInputStream(fileDescriptor.getFileDescriptor());
    FileChannel fileChannel = inputStream.getChannel();
    long startOffset = fileDescriptor.getStartOffset();
    long declaredLength = fileDescriptor.getDeclaredLength();
    return fileChannel.map(FileChannel.MapMode.READ_ONLY,startOffset,declaredLength);
  }

  private synchronized void startRecord(){
    if(recordingThread != null) return;
    shouldContinue = true;
    recordingRunnable = new Runnable() {
      @Override
      public void run() {
        record();
      }
    };
    recordingThread = new Thread(recordingRunnable);
    recordingThread.start();
  }

  private void record(){
    Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO);

    int bufferSize = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
    );

    if(bufferSize == AudioRecord.ERROR || bufferSize == AudioRecord.ERROR_BAD_VALUE){
      bufferSize = SAMPLE_RATE * 2;
    }

    short[] audioBuffer = new short[bufferSize / 2];

    record = new AudioRecord(
            MediaRecorder.AudioSource.DEFAULT,
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize
    );

    if (record.getState() != AudioRecord.STATE_INITIALIZED) {
      Log.e(LOG_TAG, "Audio Record can't initialize!");
      return;
    }

    record.startRecording();
    Log.v(LOG_TAG, "Start Recording");

    while (shouldContinue){
      int numberRead = record.read(audioBuffer, 0 , audioBuffer.length);
      int maxLength = recordingBuffer.length;
      int newRecordingOffset = recordingOffset + numberRead;
      int secondCopyLength = Math.max(0, newRecordingOffset - maxLength);
      int firstCopyLength = numberRead - secondCopyLength;

      recordingBufferLock.lock();

      try{
        System.arraycopy(
                audioBuffer,
                0,
                recordingBuffer,
                recordingOffset,
                firstCopyLength
        );
        System.arraycopy(
                audioBuffer,
                firstCopyLength,
                recordingBuffer,
                0,
                secondCopyLength
        );
        recordingOffset = newRecordingOffset % maxLength;
      } finally {
        recordingBufferLock.unlock();
      }
    }
  }

  private synchronized void startRecognition(){
    if(recognitionThread != null) return;
    shouldContinueRecognition = true;
    recognitionRunnable = new Runnable() {
      @Override
      public void run() {
        recognize();
      }
    };
    recognitionThread = new Thread(recognitionRunnable);
    recognitionThread.start();
  }

  private void recognize(){
    Log.v(LOG_TAG, "Start Recognition");

    short[] inputBuffer = new short[RECORDING_LENGTH];
    float[][] floatInputBuffer = new float[1][RECORDING_LENGTH];
    float[][][] outputScores = new float[1][32][88];
    int[] prevResult = new int[88];

    while (shouldContinueRecognition) {
      recordingBufferLock.lock();
      try{
        int maxLength = recordingBuffer.length;
        int firstCopyLength = maxLength - recordingOffset;
        int secondCopyLength = recordingOffset;
        System.arraycopy(
                recordingBuffer,
                recordingOffset,
                inputBuffer,
                0,
                firstCopyLength
        );
        System.arraycopy(
                recordingBuffer,
                0,
                inputBuffer,
                firstCopyLength,
                secondCopyLength
        );
      } finally {
        recordingBufferLock.unlock();
      }

      for (int i = 0; i < RECORDING_LENGTH; i++){
        floatInputBuffer[0][i] = inputBuffer[i] / 32767.0f;
      }

      Object[] inputArray = {floatInputBuffer};
      Map<Integer, Object> outputMap = new HashMap<>();
      outputMap.put(0, outputScores);

      long startTime = new Date().getTime();
      tfLite.runForMultipleInputsOutputs(inputArray,outputMap);
      lastProcessingTimeMs = new Date().getTime() - startTime;

      float[][][] restemp = (float[][][]) outputMap.get(0);
      int[] result = new int[88];

      for (int i = 0; i < 32; i++) {
        for (int j = 0; j < 88; j++) {
          if(restemp[0][i][j] > 0) {
            result[j] = result[j] + 1;
          }
        }
      }

      List<Integer> resultList = new ArrayList<Integer>();

      for (int i = 0; i < 88; i++) {
        int midiNum = i + 21;
        if(prevResult[i] == 0 && result[i] > 0){
//          System.out.println("[Note On] midiNum : " + midiNum);
          resultList.add(midiNum);
        }
        if(prevResult[i] > 0 && result[i] == 0){
//          System.out.println("[Note Off] midiNum" + midiNum);
        }
        prevResult[i] = result[i];
      }
      getResult(resultList);
    }
  }

  public void getResult(List<Integer> recognitionResult) {
    //passing data from platform to flutter requires ui thread
    runOnUIThread(() ->{
      if(events != null){
//        Log.v(LOG_TAG, "Result : " + recognitionResult);
        events.success(recognitionResult);
      }
    });
  }

  public void getResult(int recognitionResult) {
    //passing data from platform to flutter requires ui thread
    runOnUIThread(() ->{
      if(events != null){
        Log.v(LOG_TAG, "Result : " + recognitionResult);
        events.success(recognitionResult);
      }
    });
  }

  public synchronized void stopRecording() {
    if (recordingThread == null || shouldContinue == false ) {
      Log.d(LOG_TAG, "Recording has already stopped. Breaking stopRecording()");
      return;
    }

    shouldContinue = false;
    record.stop();
    record.release();

    recordingOffset = 0; //reset recordingOffset
    recordingThread = null;//closes recording
    Log.d(LOG_TAG, "Recording stopped.");
  }

  public synchronized void stopRecognition() {
    if (recognitionThread == null) {
      return;
    }

    Log.d(LOG_TAG, "Recognition stopped.");
    recognitionThread = null;
    shouldContinueRecognition = false;  // => ?

    //If last inference run is true, will close stream
    if (lastInferenceRun == true) {
      //passing data from platform to flutter requires ui thread
      runOnUIThread(() -> {
        if (events != null) {
          Log.d(LOG_TAG, "Recognition Stream stopped");
          events.endOfStream();
        }
      });
      lastInferenceRun = false;
    }
  }

  private void runOnUIThread(Runnable runnable) {
    if (Looper.getMainLooper() == Looper.myLooper())
      runnable.run();
    else
      handler.post(runnable);
  }
}