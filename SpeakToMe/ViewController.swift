import UIKit
import Speech

public class ViewController: UIViewController, SFSpeechRecognizerDelegate, UIPickerViewDelegate, UIPickerViewDataSource {
    
    // MARK: Properties
    
    private var speechRecognizer: SFSpeechRecognizer!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private let audioEngine = AVAudioEngine()
    
    private var pickerData: [String] = [String]()
    private let defaultLocale = "en-US"
    
     // MARK: UI
    
    @IBOutlet var picker: UIPickerView!
    
    @IBOutlet var textView : UITextView!
    
    @IBOutlet var countrySelected: UITextView!
    
    @IBOutlet var recordButton : UIButton!
    
    // MARK: UIViewController
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // Get locales
        self.pickerData = SFSpeechRecognizer.supportedLocales().map { $0.identifier } .sorted()
        
        // Disable the record buttons until authorization has been granted.
        recordButton.isEnabled = false
        
        prepareRecognizer(localeIdentifier: defaultLocale)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        
        // Select default
        if let index = self.pickerData.index(of: self.defaultLocale) {
            self.picker.selectRow(index, inComponent: 0, animated: false)
        }
        
        askForSpeechRecognitionPermissions()
    }
    
    private func askForSpeechRecognitionPermissions() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            
            var enabled: Bool = false
            var message: String?
            
            switch authStatus {
                
            case .authorized:
                enabled = true
                
            case .denied:
                enabled = false
                message = "User denied access to speech recognition"
                
            case .restricted:
                enabled = false
                message = "Speech recognition restricted on this device"
                
            case .notDetermined:
                enabled = false
                message = "Speech recognition not yet authorized"
            }
            
            /*
             The callback may not be called on the main thread. Add an
             operation to the main queue if you want to perform action on UI.
             */
            
            OperationQueue.main.addOperation {
                // Here you can perform UI action, eg with a record button
                self.recordButton.isEnabled = enabled
                if let message = message {
                    self.recordButton.setTitle(message, for: .disabled)
                }
            }
        }
    }
    
    private func prepareRecognizer(localeIdentifier: String) {
        
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))!
        speechRecognizer.delegate = self
        
        self.countrySelected.text = NSLocale(localeIdentifier: self.defaultLocale).displayName(forKey: NSLocale.Key.identifier, value: localeIdentifier) ?? ""
        
    }
    
    private func startRecording() throws {

        // Cancel the previous task if it's running.
        if let recognitionTask = self.recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(AVAudioSessionCategoryRecord)
        try audioSession.setMode(AVAudioSessionModeMeasurement)
        try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        
        self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let inputNode = audioEngine.inputNode else { fatalError("Audio engine has no input node") }
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object") }
        
        // Configure request so that results are returned before audio recording is finished
        self.recognitionRequest?.shouldReportPartialResults = true
        
        // A recognition task represents a speech recognition session.
        // We keep a reference to the task so that it can be cancelled.
        self.recognitionTask = self.speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                print(result.bestTranscription.formattedString)
                self.textView.text = result.bestTranscription.formattedString
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                self.recordButton.isEnabled = true
                self.recordButton.setTitle("Start Recording", for: [])
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        try audioEngine.start()
        
        textView.text = "(listening)"
    }

    // MARK: SFSpeechRecognizerDelegate
    
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            recordButton.isEnabled = true
            recordButton.setTitle("Start Recording", for: [])
        } else {
            recordButton.isEnabled = false
            recordButton.setTitle("Recognition not available", for: .disabled)
        }
    }
    
    // MARK: Interface Builder actions
    
    @IBAction func recordButtonTapped() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            recordButton.isEnabled = false
            recordButton.setTitle("Stopping", for: .disabled)
        } else {
            try! startRecording()
            recordButton.setTitle("Stop recording", for: [])
        }
    }
    
    // MARK: UIPickerView
    
    public func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.pickerData.count
    }
    
    public func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return self.pickerData[row]
    }
    
    public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        prepareRecognizer(localeIdentifier: self.pickerData[row])
    }
}

