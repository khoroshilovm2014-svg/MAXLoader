import UIKit

import AltStoreCore
import AltSign
import Roxas

/// Экран установки MAX из встроенного IPA.
/// Использует родной AppManager AltStore — он сам подписывает и устанавливает.
class MaxInstallViewController: UIViewController {

    // MARK: - Настройки

    /// Bundle ID из Info.plist внутри MAX.ipa
    private let maxBundleIdentifier = "ru.oneme.app"
    private let maxName = "MAX"

    // MARK: - UI

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.layer.cornerRadius = 22
        iv.clipsToBounds = true
        iv.backgroundColor = .systemBlue
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "MAX"
        l.font = .systemFont(ofSize: 28, weight: .bold)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.text = "Мессенджер от VK"
        l.font = .systemFont(ofSize: 15)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let statusLabel: UILabel = {
        let l = UILabel()
        l.text = "Готов к установке"
        l.font = .systemFont(ofSize: 14)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let progressView: UIProgressView = {
        let p = UIProgressView(progressViewStyle: .default)
        p.progress = 0
        p.isHidden = true
        p.translatesAutoresizingMaskIntoConstraints = false
        return p
    }()

    private lazy var installButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Установить MAX"
        config.cornerStyle = .large
        config.baseBackgroundColor = .systemBlue
        config.baseForegroundColor = .white

        let b = UIButton(configuration: config)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addTarget(self, action: #selector(installTapped), for: .touchUpInside)
        return b
    }()

    private var progress: Progress?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "MAX"

        setupUI()
    }

    private func setupUI() {
        view.addSubview(iconImageView)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(statusLabel)
        view.addSubview(progressView)
        view.addSubview(installButton)

        NSLayoutConstraint.activate([
            iconImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            iconImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 120),
            iconImageView.heightAnchor.constraint(equalToConstant: 120),

            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            statusLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 30),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            progressView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 20),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            installButton.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 40),
            installButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            installButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            installButton.heightAnchor.constraint(equalToConstant: 54),
        ])
    }

    // MARK: - Установка

    @objc private func installTapped() {
        // 1. Проверяем, что IPA есть в Bundle
        guard let ipaURL = Bundle.main.url(forResource: "MAX", withExtension: "ipa") else {
            showAlert(title: "Ошибка", message: "MAX.ipa не найден в приложении")
            return
        }

        // 2. Создаём объект, соответствующий AppProtocol
        let maxApp = AnyApp(
            name: self.maxName,
            bundleIdentifier: self.maxBundleIdentifier,
            url: ipaURL
        )

        // 3. Запускаем установку через родной AppManager
        installButton.isEnabled = false
        progressView.isHidden = false
        progressView.progress = 0
        updateStatus("Подготовка...")

        self.progress = AppManager.shared.install(
            maxApp,
            presentingViewController: self
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.handleInstallResult(result)
            }
        }

        // Подписываемся на прогресс
        if let progress = self.progress {
            progress.publisher(for: \.fractionCompleted)
                .receive(on: RunLoop.main)
                .sink { [weak self] fraction in
                    self?.progressView.progress = Float(fraction)
                    self?.updateStatus(self?.stageText(Float(fraction)) ?? "")
                }
                .store(in: &cancellables)
        }
    }

    private var cancellables: Set<AnyCancellable> = []

    private func handleInstallResult(_ result: Result<InstalledApp, Error>) {
        installButton.isEnabled = true

        switch result {
        case .success:
            progressView.progress = 1.0
            updateStatus("✓ Установлено")
            showAlert(title: "Готово", message: "MAX установлен на iPhone")

        case .failure(let error):
            updateStatus("Ошибка: \(error.localizedDescription)")
            showAlert(title: "Ошибка", message: error.localizedDescription)
        }
    }

    private func stageText(_ progress: Float) -> String {
        switch progress {
        case 0..<0.2:   return "Авторизация Apple ID..."
        case 0.2..<0.4: return "Скачивание сертификата..."
        case 0.4..<0.6: return "Подпись MAX..."
        case 0.6..<0.9: return "Отправка на iPhone..."
        case 0.9..<1.0: return "Установка..."
        default:        return "Завершение..."
        }
    }

    private func updateStatus(_ text: String) {
        statusLabel.text = text
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

import Combine
