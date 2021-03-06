//
//  GameViewController.swift
//  PhonemoQuiz
//
//  Created by Thanapat Sorralump on 19/3/2561 BE.
//  Copyright © 2561 Thanapat Sorralump. All rights reserved.
//

import UIKit
import AVFoundation
import Speech
import SDWebImage

class GameViewController: UIViewController, SFSpeechRecognizerDelegate, DismissViewDelegate, FetchDataDelegate {

  //MARK:- Variables and IBOutlet
  //MARK: Speech Recognition Variables
  fileprivate let audioEngine = AVAudioEngine()
  fileprivate let speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
  fileprivate var request: SFSpeechAudioBufferRecognitionRequest?
  fileprivate var recognitionTask: SFSpeechRecognitionTask?
  
  //MARK: Game Variables
  fileprivate var randomWord = WordGenerator.shared.ramdomWord()
  fileprivate var resultWords = [String]()
  fileprivate var answerWord: ChallengeWord? {
    didSet {
      questionLabel.text = answerWord?.ipa
    }
  }
  fileprivate var score = 0 {
    didSet {
      scoreUser.text = "Score: \(score)"
    }
  }
  
  //MARK: Sound  Variables
  fileprivate let micSound = Bundle.main.url(forResource: "mic", withExtension: "mp3")
  fileprivate let correctSound = Bundle.main.url(forResource: "correct", withExtension: "mp3")
  fileprivate let wrongSound = Bundle.main.url(forResource: "wrong", withExtension: "mp3")
  fileprivate var audioPlayer = AVAudioPlayer()
  
  //MARK: UI Variables
  @IBOutlet fileprivate weak var scoreUser: UILabel!
  @IBOutlet fileprivate weak var questionLabel: UILabel!
  @IBOutlet fileprivate weak var micBtn: UIButton!
  @IBOutlet fileprivate weak var profilePic: UIImageView!
  
  //MARK:- Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()
    view.setupStatusBar(view: view)
    print(randomWord) //****
    setupUI()
    setupProfilePicture()
    Audio.shared.useAllSpeaker()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    view.showLoading()
    fetchWordData(word: randomWord)
  }
  
  //MARK:- IBActions
  @IBAction fileprivate func quitGame(_ sender: UIButton) {
    let alert = UIAlertController(title: "ออกจากเกม", message: "คุณต้องการออกจากเกมหรือไม่ (คะแนนจะไม่ถูกบันทึก)", preferredStyle: .alert)
    let yesBtn = UIAlertAction(title: "ใช่", style: .cancel) { (_) in self.dismiss(animated: true, completion: nil) }
    let noBtn = UIAlertAction(title: "ไม่", style: .default, handler: nil)
    alert.addAction(yesBtn)
    alert.addAction(noBtn)
    
    present(alert, animated: true, completion: nil)
  }
  
  @IBAction fileprivate func recordSoundBtnTouch(_ sender: UIButton) {
    Audio.shared.setupAudioFile(audioPlayer: &audioPlayer, sound: micSound).play()
    micBtn.buttonAnimateSpring(animation: {
      self.micBtn.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
      self.micBtn.backgroundColor = .red
      self.micBtn.isEnabled = false
      self.micBtn.layer.cornerRadius = self.micBtn.frame.width / 2
    },completion: { (_) in
      self.recordAndRecognizeSpeech()
      DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 2, execute: {
        print(self.resultWords) //****
        self.stopRecording()
      })
    })
  }
  
  //MARK:- Call APIs Functions
  func fetchWordData(word: String) {
    OxfordAPIService.shared.fetchWordData(randomWord: word, completion: { (result) in
      self.answerWord = result
      self.view.hideLoading()
    }) {
      let randomNewWord = WordGenerator.shared.ramdomWord()
      self.randomWord = randomNewWord
      self.fetchWordData(word: randomNewWord)
    }
  }
  
  //MARK:- Delegate Functions
  func viewDismiss() {
    self.dismiss(animated: true, completion: nil)
  }
  
  func fetchNewWord() {
    view.showLoading()
    randomWord = WordGenerator.shared.ramdomWord()
    print(randomWord)//*****
    fetchWordData(word: randomWord)
  }
  
  //MARK:- Setup Functions
  fileprivate func setupUI() {
    micBtn.layer.cornerRadius = 15
    profilePic.layer.cornerRadius = profilePic.frame.height/2
  }
  
  fileprivate func btnAnimBack() {
    self.micBtn.buttonAnimateSpring(animation: {
      self.micBtn.transform = .identity
      self.micBtn.backgroundColor = UIColor.orangePhonemo
      self.micBtn.isEnabled = true
      self.micBtn.layer.cornerRadius = 15
    }) { (_) in
      self.checkRecordingResult()
    }
  }
  
  fileprivate func setupProfilePicture() {
    UserAPIService.shared.fetchProfileData { (data) in
      let profileURL = URL(string: data[0]["picurl"].stringValue)
      self.profilePic.sd_setImage(with: profileURL, placeholderImage: #imageLiteral(resourceName: "profile"))
    }
  }
  
  //MARK: Record and Recognition
  fileprivate func recordAndRecognizeSpeech() {
    WordRecognition.shared.recordSpeech(request: &request, audioEngine: audioEngine) { (audioEngine, request)  in
      do {
        try audioEngine.start()
        self.resultWords = []
      } catch {
        Alert.shared.alertResponseOnly(title: "Speech Recognizer Error", message: "Audio Engine ทำงานผิดพลาด", showAlertCompletion: { (alert) in
          self.present(alert, animated: true, completion: nil)
        })
        return print(error)
      }
      
      WordRecognition.shared.recognitionTask(recognitionTask: &recognitionTask, speechRecognizer: speechRecognizer, request: request, completion: { (result) in
        guard let result = result else { return }
        let stringResult = result.bestTranscription.formattedString
        self.resultWords.append(stringResult)
      })
    }
  }
  
  fileprivate func stopRecording() {
    WordRecognition.shared.stopRecording(request: request, audioEngine: audioEngine, recognitionTask: &self.recognitionTask, completion: {
      DispatchQueue.main.async {
        self.btnAnimBack()
      }
    })
  }
  
  //MARK:- Check Recording Result and Push new ViewController
  fileprivate func checkRecordingResult() {
    let filterResult = resultWords.filter { (word) -> Bool in
      return word.lowercased() == randomWord
    }
    
    if filterResult.count > 0 {
      score += 50
      pushModal(type: .correct)
    } else {
      pushModal(type: .wrong)
    }
  }
  
  enum typeModal {
    case correct
    case wrong
  }
  
  fileprivate func pushModal(type: typeModal) {
    if type == .correct {
      let viewController = storyboard?.instantiateViewController(withIdentifier: "correct") as! CorrectViewController
      viewController.answer = answerWord
      viewController.delegate = self
      presentVC(viewController: viewController, audioPlayer: Audio.shared.setupAudioFile(audioPlayer: &audioPlayer, sound: correctSound))
    } else if type == .wrong {
      let viewController = storyboard?.instantiateViewController(withIdentifier: "wrong") as! WrongViewController
      viewController.delegate = self
      viewController.answer = answerWord
      viewController.score = self.score
      presentVC(viewController: viewController, audioPlayer: Audio.shared.setupAudioFile(audioPlayer: &audioPlayer, sound: wrongSound))
    }
  }
  
  fileprivate func presentVC(viewController: UIViewController, audioPlayer: AVAudioPlayer) {
    audioPlayer.play()
    viewController.modalPresentationStyle = .overCurrentContext
    present(viewController, animated: false, completion: nil)
  }

}
