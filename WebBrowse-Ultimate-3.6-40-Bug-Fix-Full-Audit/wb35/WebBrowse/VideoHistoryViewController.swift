import UIKit

final class VideoHistoryViewController: UITableViewController {
    private var items: [WatchedVideo] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Recently Watched"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(close))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Clear", style: .plain, target: self, action: #selector(clearHistory))
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "HistoryCell")
        NotificationCenter.default.addObserver(self, selector: #selector(historyChanged), name: .webBrowseVideoHistoryChanged, object: nil)
        reloadData()
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func close() { dismiss(animated: true) }
    @objc private func historyChanged() { reloadData() }

    private func reloadData() {
        items = VideoHistory.shared.all()
        tableView.reloadData()
        navigationItem.rightBarButtonItem?.isEnabled = !items.isEmpty
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { items.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "HistoryCell", for: indexPath)
        let item = items[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = item.title
        content.secondaryText = "\(item.sourceHost) • \(Self.dateFormatter.string(from: item.watchedAt))"
        content.image = UIImage(systemName: "clock.arrow.circlepath")
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = items[indexPath.row]
        let sheet = UIAlertController(title: item.title, message: item.sourcePageURL, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Open Website", style: .default) { [weak self] _ in
            guard let self, let url = URL(string: item.sourcePageURL) else { return }
            self.dismiss(animated: true) { NotificationCenter.default.post(name: .webBrowseOpenURLFromHistory, object: url) }
        })
        sheet.addAction(UIAlertAction(title: "Share Website Link", style: .default) { [weak self] _ in
            guard let self else { return }
            let vc = UIActivityViewController(activityItems: [item.sourcePageURL], applicationActivities: nil)
            if let pop = vc.popoverPresentationController { pop.sourceView = self.view; pop.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 1, height: 1) }
            self.present(vc, animated: true)
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = sheet.popoverPresentationController, let cell = tableView.cellForRow(at: indexPath) { pop.sourceView = cell; pop.sourceRect = cell.bounds }
        present(sheet, animated: true)
    }

    @objc private func clearHistory() {
        let alert = UIAlertController(title: "Clear Recently Watched?", message: "This removes the saved video titles and exact website links from WebBrowse.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            VideoHistory.shared.clear { [weak self] in self?.reloadData() }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()
}

extension Notification.Name {
    static let webBrowseOpenURLFromHistory = Notification.Name("WebBrowseOpenURLFromHistory")
}
