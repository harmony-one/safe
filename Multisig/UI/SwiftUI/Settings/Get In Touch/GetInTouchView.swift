//
//  GetInTouchView.swift
//  Multisig
//
//  Created by Dmitry Bespalov on 13.05.20.
//  Copyright © 2020 Gnosis Ltd. All rights reserved.
//

import SwiftUI

struct GetInTouchView: View {

    typealias CommsChannel = (url: URL, icon: String, text: String)

    @ObservedObject
    var theme: Theme = App.shared.theme

    private static let contact = App.configuration.contact

    
    let channels: [CommsChannel] = [
        (contact.discordURL, "ico-discord", "Discord"),
        (contact.twitterURL, "ico-twitter", "Twitter"),
        (contact.telegramURL, "ico-telegram", "Telegram"),
        (contact.youtubeURL, "ico-youtube", "YouTube"),
        (contact.instagramURL, "ico-instagram", "Instagram"),
    ]

    var body: some View {
        List {
            ForEach(channels, id: \.url) { item in
                BrowserLink(title: item.text, url: item.url, iconName: item.icon)
            }
        }
        .onAppear {
            Tracker.trackEvent(.settingsAppSupport)
        }
        .navigationBarTitle("Links", displayMode: .inline)
    }
}

struct GetInTouchView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            GetInTouchView()
        }
    }
}
