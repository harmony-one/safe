//
//  HeaderViewController.swift
//  Multisig
//
//  Created by Dmitry Bespalov on 21.10.20.
//  Copyright © 2020 Gnosis Ltd. All rights reserved.
//

import UIKit
import SwiftCryptoTokenFormatter

/// Header bar will adapt to the devices size
final class HeaderViewController: ContainerViewController {
    @IBOutlet private weak var stackView: UIStackView!
    @IBOutlet private weak var headerBar: UIView!
    @IBOutlet private weak var barShadowView: UIImageView!
    @IBOutlet private weak var safeBarView: SafeBarView!
    @IBOutlet private weak var noSafeBarView: NoSafeBarView!
    @IBOutlet private weak var switchSafeButton: UIButton!
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var headerBarHeightConstraint: NSLayoutConstraint!

    private var rootViewController: UIViewController?
    private var currentDataTask: URLSessionTask?

    var clientGatewayService = App.shared.clientGatewayService
    var notificationCenter = NotificationCenter.default
    
    private var addSafeFlow: AddSafeFlow!
    private var claimTokenFlow: ClaimSafeTokenFlow!
    private var createSafeFlow: CreateSafeFlow!
    
    var gatewayService = App.shared.clientGatewayService
    var completion: (_ address: Address, _ safeVersion: String) -> Void = { _, _ in }
    var chain: SCGModels.Chain!
    var preselectedAddress: String?
    private var loadSafeTask: URLSessionTask?
    
    private var loadFirstPageDataTask: URLSessionTask?
    private var loadNextPageDataTask: URLSessionTask?

    private var model = NetworksListViewModel()
    var completions: (SCGModels.Chain) -> Void = { _ in }


    convenience init(rootViewController: UIViewController) {
        self.init(namedClass: nil)
        self.rootViewController = rootViewController
        viewControllers = [rootViewController]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        headerBar.backgroundColor = .backgroundSecondary
        safeBarView.addTarget(self, action: #selector(didTapSafeBarView(_:)), for: .touchUpInside)
        safeBarView.set { [unowned self] in
            guard let safe = try? Safe.getSelected() else { return }
            claimTokenFlow = ClaimSafeTokenFlow(safe: safe) { [unowned self] _ in
                claimTokenFlow = nil
            }
            Tracker.trackEvent(.userClaimOpen)
            present(flow: claimTokenFlow)
        }

        reloadHeaderBar()
        displayRootController()
        addObservers()
        headerBarHeightConstraint.constant = ScreenMetrics.safeHeaderHeight
        reloadSafeData()
    }
    
    func loadHarmony() {
        loadFirstPageDataTask?.cancel()
        loadNextPageDataTask?.cancel()
        
        loadFirstPageDataTask = clientGatewayService.asyncChains { [weak self] result in
            guard let `self` = self else { return }
            switch result {
            case .failure(let error):
                DispatchQueue.main.async { [weak self] in
                    guard let `self` = self else { return }
                    // ignore cancellation error due to cancelling the
                    // currently running task. Otherwise user will see
                    // meaningless message.
                    if (error as NSError).code == URLError.cancelled.rawValue &&
                        (error as NSError).domain == NSURLErrorDomain {
                        return
                    }
                    self.onError(GSError.error(description: "Failed to load networks", error: error))
                }
            case .success(let page):
                let results = page.results.filter { $0.chainId == "1666600000" }
                var model = NetworksListViewModel(results)
                model.next = page.next
                
                DispatchQueue.main.async { [weak self] in
                    guard let `self` = self else { return }
                    self.model = model
                    guard let chain = model.models.first else  {
                        return
                    }
                    do {
                        // (1) validate that the text is address
                        let address = try Address.addressWithPrefix(text: "0x372ECCF90a7c0BF658c398738f0695D85CdaC1ea")
                        guard (address.prefix ?? chain.shortName) == chain.shortName else {
                            // addressField.setError(GSError.AddressMismatchNetwork())
                            return
                        }
                        // (2) and that there's no such safe already
                        let exists = Safe.exists(address.checksummed, chainId: chain.id)
                        if exists { throw GSError.SafeAlreadyExists() }
                        
                        loadSafeTask = gatewayService.asyncSafeInfo(safeAddress: address,
                                                                    chainId: chain.id,
                                                                    completion: { [weak self] result in
                            switch result {
                            case .failure(let error):
                                DispatchQueue.main.async { [weak self] in
                                    guard let `self` = self else { return }
                                    if (error as NSError).code == URLError.cancelled.rawValue &&
                                        (error as NSError).domain == NSURLErrorDomain {
                                        return
                                    } else if error is GSError.EntityNotFound {
                                        
                                        App.shared.snackbar.show(
                                            error: GSError.error(description: "Can’t use this address", error: error))
                                    } else {
                                        App.shared.snackbar.show(
                                            error: GSError.error(description: "Can’t use this address", error: error))
                                    }
                                }
                            case .success(let info):
                                DispatchQueue.main.async { [weak self] in
                                    guard let `self` = self else { return }
                                    // (4) and its mastercopy is supported
                                    guard App.shared.gnosisSafe.isSupported(info.version) else {
                                        App.shared.snackbar.show(
                                            error: GSError.error(description: "Can’t use this address", error: GSError.UnsupportedImplementationCopy()))
                                        return
                                    }
                                    self.addSafe(address: address, chain: chain, safeVersion: info.version)
                                    reloadSafeData()
                                }
                            }
                        })
                    } catch {
                        App.shared.snackbar.show(
                            error: GSError.error(description: "Can’t use this address", error: error))
                    }
                }
            }
        }
    }
    
    func addSafe(address: Address, chain: SCGModels.Chain, safeVersion: String) {
        let coreDataChain = Chain.createOrUpdate(chain)
        Safe.create(
            address: address.checksummed,
            version: safeVersion,
            name: "h.country",
            chain: coreDataChain)
        App.shared.notificationHandler.safeAdded(address: address)
    }
    
    func onError(_ error: DetailedLocalizedError) {
       App.shared.snackbar.show(error: error)
   }

    private func addObservers() {
        let updateNotifications: [NSNotification.Name] = [
            .selectedSafeChanged, .selectedSafeUpdated, .ownerKeyImported, .ownerKeyRemoved, .initiateTxNotificationReceived
        ]
        for name in updateNotifications {
            notificationCenter.addObserver(self,
                                           selector: #selector(didReceiveUpdateNotification(_:)),
                                           name: name,
                                           object: nil)
        }
        notificationCenter.addObserver(
            self,
            selector: #selector(reloadSafeData),
            name: UIScene.willEnterForegroundNotification,
            object: nil)
    }

    private func displayRootController() {
        assert(!viewControllers.isEmpty)
        displayChild(at: 0, in: contentView)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.isHidden = false
    }

    @IBAction private func didTapSwitchSafe(_ sender: Any) {
        let switchSafesVC = SwitchSafesViewController()

        switchSafesVC.onAddSafe = { [weak self] in
            Tracker.trackEvent(.addSafeFromSwitchSafes)
            self?.dismiss(animated: false) {
                self?.addSafe()
            }
        }

        switchSafesVC.onCreateSafe = { [weak self] in
            // Create Safe Flow
            Tracker.trackEvent(.createSafeFromSwitchSafes)
            self?.dismiss(animated: true) { [weak self] in
                guard let self = self else { return }
                self.createSafeFlow = CreateSafeFlow(completion: { [weak self] _ in
                    self?.createSafeFlow = nil
                })
                self.present(flow: self.createSafeFlow, dismissableOnSwipe: false)
            }
        }

        let nav = UINavigationController(rootViewController: switchSafesVC)
        present(nav, animated: true)
    }
    
    private func addSafe() {
        addSafeFlow = AddSafeFlow(completion: { [weak self] _ in
            self?.addSafeFlow = nil
        })
        present(flow: addSafeFlow)
    }

    @objc private func didTapSafeBarView(_ sender: Any) {
//        let vc = SafeInfoViewController(nibName: nil, bundle: nil)
//        vc.modalPresentationStyle = .overFullScreen
//        vc.modalTransitionStyle = .crossDissolve
//        present(vc, animated: true, completion: nil)
        
        Pasteboard.string = safeBarView.address.description
        App.shared.snackbar.show(message: "Copied to clipboard", duration: 2)
    }

    @objc private func didReceiveUpdateNotification(_ notification: Notification) {
        if [.selectedSafeChanged, .initiateTxNotificationReceived].contains(notification.name) {
            reloadSafeData()
        }
        reloadHeaderBar()
    }

    @objc private func reloadHeaderBar() {
        do {
            let selectedSafe = try Safe.getSelected()
            let hasSafe = selectedSafe != nil
            safeBarView.isHidden = !hasSafe
          //  switchSafeButton.isHidden = !hasSafe
            noSafeBarView.isHidden = hasSafe

            if let safe = selectedSafe {
                safeBarView.setName(safe.displayName)
             //   safeBarView.setReadOnly(safe.isReadOnly)

                switch safe.safeStatus {
                case .deployed:
                    safeBarView.setAddress(safe.addressValue, prefix: safe.chain!.shortName)

                case .deploying, .indexing:
                    safeBarView.setAddress(safe.addressValue, grayscale: true)
                    safeBarView.setDetail(text: "Creating in progress...")

                case .deploymentFailed:
                    safeBarView.setAddress(safe.addressValue, grayscale: true)
                    safeBarView.setDetail(text: "Failed to create", style: .bodyError)
                }
            }
        } catch {
            App.shared.snackbar.show(
                error: GSError.error(description: "Failed to update selected safe", error: error))
        }
    }

    @objc private func reloadSafeData() {
        currentDataTask?.cancel()
        do {
            guard let safe = try Safe.getSelected() else {
                loadHarmony()
                return
                
            }

            safeBarView.set(safeTokenClaimable: ClaimingAppController.isAvailable(chain: safe.chain!))

            currentDataTask = clientGatewayService.asyncSafeInfo(safeAddress: safe.addressValue,
                                                                 chainId: safe.chain!.id!) { [weak self] result in
                DispatchQueue.main.async { [weak self] in
                    switch result {
                    case .failure(let error):
                        // ignore cancellation error due to cancelling the
                        // currently running task.
                        if (error as NSError).code == URLError.cancelled.rawValue &&
                            (error as NSError).domain == NSURLErrorDomain {
                            return
                        }
                        LogService.shared.error("Failed to reload Safe Account info: \(error)")
                    case .success(let safeInfo):
                        safe.update(from: safeInfo)
                        self?.reloadHeaderBar()
                    }
                }
            }
        } catch {
            LogService.shared.error("Failed to reload Safe Account info: \(error)")
        }
    }
}
