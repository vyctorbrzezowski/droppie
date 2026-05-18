import AppKit
import DroppieCore
import SwiftUI

struct SetupView: View {
  @ObservedObject var model: DroppieModel
  @State private var providerKind: UploadProviderKind = .hereNow
  @State private var isSetupGuideExpanded = true

  var body: some View {
    HStack(spacing: 0) {
      providerSidebar

      Rectangle()
        .fill(SettingsStyle.separator)
        .frame(width: 1)

      detailPane
    }
    .frame(minWidth: 900, minHeight: 680)
    .background(.regularMaterial)
    .onAppear {
      providerKind = model.editingProvider.kind
    }
  }

  private var providerSidebar: some View {
    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 10) {
        Text("Providers")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 6)

        ScrollView {
          VStack(alignment: .leading, spacing: 2) {
            ForEach(model.providers) { provider in
              ProviderSidebarRow(
                provider: provider,
                kind: provider.kind,
                isSelected: provider.id == model.selectedProviderID
              ) {
                model.selectProvider(provider)
                providerKind = provider.kind
                isSetupGuideExpanded = true
              }
            }
          }
        }
      }
      .padding(10)
      .padding(.top, SettingsStyle.titlebarInset)

      Spacer(minLength: 0)

      Rectangle()
        .fill(SettingsStyle.separator)
        .frame(height: 1)

      HStack(spacing: 8) {
        Menu {
          ForEach(UploadProviderKind.allCases) { kind in
            Button(kind.title) {
              providerKind = kind
              model.startNewProvider(kind: kind)
              isSetupGuideExpanded = true
            }
          }
        } label: {
          Label("Add", systemImage: "plus")
            .labelStyle(.titleAndIcon)
        }
        .menuStyle(.button)
        .controlSize(.small)

        Spacer()

        Button(role: .destructive) {
          model.deleteSelectedProvider()
        } label: {
          Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .disabled(model.selectedProviderID == nil)
        .help("Delete provider")
      }
      .padding(10)
    }
    .frame(width: 224)
    .background {
      ZStack(alignment: .topLeading) {
        Rectangle()
          .fill(.regularMaterial)

        LinearGradient(
          colors: [
            Color.white.opacity(0.055),
            Color.primary.opacity(0.018),
            Color.clear
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .blendMode(.plusLighter)
        .opacity(0.65)
      }
    }
  }

  private var detailPane: some View {
    ScrollView {
      VStack(spacing: 0) {
        SettingsHero(
          title: model.editingProvider.kind.title,
          kind: model.editingProvider.kind
        )

        VStack(spacing: 16) {
          ProviderSetupGuide(
            guide: guide(for: model.editingProvider.kind),
            isExpanded: $isSetupGuideExpanded
          )

          providerBasics
          providerFields
          saveSection
        }
        .frame(maxWidth: 640)
        .padding(.horizontal, 16)
        .padding(.bottom, 18)
      }
      .frame(maxWidth: .infinity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(nsColor: .windowBackgroundColor).opacity(0.72))
  }

  private var providerBasics: some View {
    SettingsSection {
      SettingsPickerRow(title: "Provider", selection: $providerKind) {
        ForEach(UploadProviderKind.allCases) { kind in
          Text(kind.title).tag(kind)
        }
      }
      .onChange(of: providerKind) { _, newValue in
        if model.editingProvider.kind != newValue {
          model.startNewProvider(kind: newValue)
          isSetupGuideExpanded = true
        }
      }

      SettingsDivider()

      SettingsToggleRow(
        title: "Copy link after upload",
        isOn: $model.editingProvider.copyLinkAfterUpload
      )
    }
  }

  @ViewBuilder
  private var providerFields: some View {
    switch model.editingProvider.kind {
    case .hereNow:
      SettingsSection(title: "Connection") {
        SettingsTextFieldRow("API URL", text: $model.editingProvider.hereNowAPIBaseURL, placeholder: "https://api.here.now")
        SettingsDivider()
        SettingsSecureFieldRow("API key", text: $model.credentialDraft, placeholder: "API key")
      }

    case .imgur:
      SettingsSection(title: "Connection") {
        SettingsTextFieldRow("API URL", text: $model.editingProvider.imgurAPIBaseURL, placeholder: "https://api.imgur.com")
        SettingsDivider()
        SettingsSecureFieldRow("Client ID", text: $model.credentialDraft, placeholder: "Client ID")
      }

    case .amazonS3:
      SettingsSection(title: "Storage") {
        SettingsPickerRow(title: "Authentication", selection: $model.editingProvider.s3AuthMode) {
          ForEach(S3AuthMode.allCases) { mode in
            Text(mode.title).tag(mode)
          }
        }
        SettingsDivider()
        SettingsTextFieldRow("Bucket", text: $model.editingProvider.s3Bucket, placeholder: "my-bucket")
        SettingsDivider()
        SettingsTextFieldRow("Region", text: $model.editingProvider.s3Region, placeholder: "us-east-1")
        SettingsDivider()
        SettingsTextFieldRow("Public base URL", text: $model.editingProvider.s3PublicBaseURL, placeholder: "https://cdn.example.com")
        SettingsDivider()
        SettingsTextFieldRow("Key prefix", text: $model.editingProvider.s3KeyPrefix, placeholder: "uploads")
      }

      if model.editingProvider.s3AuthMode == .accessKeys {
        SettingsSection(title: "Credentials") {
          SettingsTextFieldRow("Access Key ID", text: $model.accessKeyIDDraft, placeholder: "AKIA...")
          SettingsDivider()
          SettingsSecureFieldRow("Secret Access Key", text: $model.secretAccessKeyDraft, placeholder: "Secret key")
          SettingsDivider()
          SettingsSecureFieldRow("Session token", text: $model.sessionTokenDraft, placeholder: "Optional")
        }
      } else {
        SettingsSection(title: "AWS config") {
          SettingsTextFieldRow("AWS profile", text: $model.editingProvider.s3Profile, placeholder: "default")
        }
      }

    case .cloudflareR2:
      SettingsSection(title: "Storage") {
        SettingsTextFieldRow("Account ID", text: $model.editingProvider.cloudflareAccountID, placeholder: "Cloudflare account ID")
        SettingsDivider()
        SettingsTextFieldRow("Bucket", text: $model.editingProvider.s3Bucket, placeholder: "my-bucket")
        SettingsDivider()
        SettingsTextFieldRow("Public base URL", text: $model.editingProvider.s3PublicBaseURL, placeholder: "https://files.example.com")
        SettingsDivider()
        SettingsTextFieldRow("Key prefix", text: $model.editingProvider.s3KeyPrefix, placeholder: "uploads")
      }

      SettingsSection(title: "Credentials") {
        SettingsTextFieldRow("Access Key ID", text: $model.accessKeyIDDraft, placeholder: "Access key ID")
        SettingsDivider()
        SettingsSecureFieldRow("Secret Access Key", text: $model.secretAccessKeyDraft, placeholder: "Secret key")
      }

    case .googleDrive:
      SettingsSection(title: "Connection") {
        SettingsTextFieldRow("API URL", text: $model.editingProvider.googleDriveAPIBaseURL, placeholder: "https://www.googleapis.com")
        SettingsDivider()
        SettingsSecureFieldRow("Access token", text: $model.credentialDraft, placeholder: "Access token")
      }

      SettingsSection(title: "Destination") {
        SettingsTextFieldRow("Folder ID", text: $model.editingProvider.googleDriveFolderID, placeholder: "Folder ID")
      }

    case .dropbox:
      SettingsSection(title: "Connection") {
        SettingsTextFieldRow("API URL", text: $model.editingProvider.dropboxAPIBaseURL, placeholder: "https://api.dropboxapi.com")
        SettingsDivider()
        SettingsTextFieldRow("Content API URL", text: $model.editingProvider.dropboxContentAPIBaseURL, placeholder: "https://content.dropboxapi.com")
        SettingsDivider()
        SettingsSecureFieldRow("Access token", text: $model.credentialDraft, placeholder: "Access token")
      }

      SettingsSection(title: "Destination") {
        SettingsTextFieldRow("Folder path", text: $model.editingProvider.dropboxPathPrefix, placeholder: "/Droppie")
      }

    case .s3Compatible:
      SettingsSection(title: "Storage") {
        SettingsTextFieldRow("Bucket", text: $model.editingProvider.s3Bucket, placeholder: "my-bucket")
        SettingsDivider()
        SettingsTextFieldRow("Public base URL", text: $model.editingProvider.s3PublicBaseURL, placeholder: "https://cdn.example.com")
        SettingsDivider()
        SettingsTextFieldRow("Key prefix", text: $model.editingProvider.s3KeyPrefix, placeholder: "uploads")
        SettingsDivider()
        SettingsTextFieldRow("Region", text: $model.editingProvider.s3Region, placeholder: "auto")
        SettingsDivider()
        SettingsTextFieldRow("Endpoint URL", text: $model.editingProvider.s3EndpointURL, placeholder: "https://s3.example.com")
      }

      SettingsSection(title: "Credentials") {
        SettingsTextFieldRow("Access Key ID", text: $model.accessKeyIDDraft, placeholder: "Access key ID")
        SettingsDivider()
        SettingsSecureFieldRow("Secret Access Key", text: $model.secretAccessKeyDraft, placeholder: "Secret key")
      }
    }
  }

  private var saveSection: some View {
    SettingsSection {
      HStack {
        Spacer()
        Button("Save") {
          model.saveEditingProvider()
        }
        .keyboardShortcut(.defaultAction)
        .controlSize(.regular)
      }
      .padding(12)
    }
  }

  private func guide(for kind: UploadProviderKind) -> ProviderGuide {
    switch kind {
    case .hereNow:
      return ProviderGuide(
        intro: "Use your here.now API key for permanent uploads owned by your account.",
        steps: [
          "Open here.now and create or copy an API key.",
          "Keep the default API URL unless you are using a custom endpoint.",
          "Paste the API key below and save the provider."
        ],
        links: [
          .init(title: "Open here.now", url: "https://here.now")
        ]
      )

    case .imgur:
      return ProviderGuide(
        intro: "Imgur accepts anonymous image uploads with a Client ID.",
        steps: [
          "Create an Imgur OAuth application.",
          "Choose anonymous usage if you only need public image links.",
          "Copy the Client ID and paste it below."
        ],
        links: [
          .init(title: "Create Imgur app", url: "https://api.imgur.com/oauth2/addclient"),
          .init(title: "Imgur apps", url: "https://imgur.com/account/settings/apps")
        ]
      )

    case .amazonS3:
      return ProviderGuide(
        intro: "S3 needs a bucket, a public URL path, and credentials allowed to upload objects.",
        steps: [
          "Create or choose an S3 bucket.",
          "Make uploaded objects reachable through a public bucket policy, CloudFront, or another public base URL.",
          "Use access keys with PutObject permission, or switch Authentication to AWS profile."
        ],
        links: [
          .init(title: "S3 buckets", url: "https://s3.console.aws.amazon.com/s3/buckets"),
          .init(title: "IAM access keys", url: "https://console.aws.amazon.com/iam/home#/security_credentials")
        ]
      )

    case .cloudflareR2:
      return ProviderGuide(
        intro: "R2 uses S3-compatible access keys plus your Cloudflare account ID.",
        steps: [
          "Create or choose an R2 bucket.",
          "Create R2 API credentials with object read/write access.",
          "Set a public bucket URL or custom domain, then paste that as the public base URL."
        ],
        links: [
          .init(title: "Cloudflare dashboard", url: "https://dash.cloudflare.com/"),
          .init(title: "R2 API tokens", url: "https://developers.cloudflare.com/r2/api/tokens/")
        ]
      )

    case .googleDrive:
      return ProviderGuide(
        intro: "Google Drive uploads need an access token with Drive file access.",
        steps: [
          "Create or choose a Google OAuth client.",
          "Generate an access token with Drive file scope.",
          "Optionally paste a folder ID; Droppie will upload there and create a public view link."
        ],
        links: [
          .init(title: "Google API credentials", url: "https://console.cloud.google.com/apis/credentials"),
          .init(title: "OAuth playground", url: "https://developers.google.com/oauthplayground/")
        ]
      )

    case .dropbox:
      return ProviderGuide(
        intro: "Dropbox works best with an App Folder token and sharing permissions.",
        steps: [
          "Create a Dropbox app with App Folder access.",
          "Grant file upload and sharing permissions.",
          "Generate an access token and paste a folder path for uploads."
        ],
        links: [
          .init(title: "Dropbox apps", url: "https://www.dropbox.com/developers/apps"),
          .init(title: "API Explorer", url: "https://dropbox.github.io/dropbox-api-v2-explorer/")
        ]
      )

    case .s3Compatible:
      return ProviderGuide(
        intro: "Use this for MinIO, Wasabi, Backblaze B2, or another service with an S3 API.",
        steps: [
          "Collect the endpoint URL, bucket, region, and access keys.",
          "Configure a public base URL for the uploaded objects.",
          "Save the provider and test with a small file first."
        ],
        links: []
      )
    }
  }

}

private enum SettingsStyle {
  static let titlebarInset: CGFloat = 52
  static let fieldWidth: CGFloat = 320
  static let sidebar = Color.primary.opacity(0.025)
  static let surface = Color.primary.opacity(0.028)
  static let surfaceHover = Color.primary.opacity(0.052)
  static let control = Color.primary.opacity(0.064)
  static let field = Color.primary.opacity(0.050)
  static let selected = Color.primary.opacity(0.095)
  static let separator = Color.primary.opacity(0.095)
  static let border = Color.primary.opacity(0.055)
  static let fieldBorder = Color.primary.opacity(0.115)
}

private struct ProviderGuide {
  struct Link: Identifiable {
    var title: String
    var url: String
    var id: String { url }
  }

  var intro: String
  var steps: [String]
  var links: [Link]
}

private struct ProviderSidebarRow: View {
  var provider: ProviderSettings
  var kind: UploadProviderKind
  var isSelected: Bool
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        ProviderLogo(kind: kind, size: 22)

        Text(provider.name)
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.primary)
          .lineLimit(1)

        Spacer(minLength: 0)
      }
      .frame(height: 32)
      .padding(.horizontal, 6)
      .background(
        isSelected ? SettingsStyle.selected : Color.clear,
        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

private struct SettingsHero: View {
  var title: String
  var kind: UploadProviderKind

  var body: some View {
    ZStack {
      ProviderHeroDecoration(kind: kind)

      VStack(spacing: 8) {
        ProviderLogo(kind: kind, size: 64)
          .padding(.bottom, 8)

        Text(title)
          .font(.system(size: 27, weight: .semibold))
          .foregroundStyle(.primary)
          .lineLimit(1)
      }
      .padding(.top, 20)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 220)
    .clipped()
  }
}

private struct ProviderHeroDecoration: View {
  var kind: UploadProviderKind
  @State private var isBreathing = false

  private var accent: Color {
    providerAccent(for: kind)
  }

  var body: some View {
    GeometryReader { proxy in
      let width = proxy.size.width
      let height = proxy.size.height
      let centerX = width / 2
      let centerY = height * 0.18

      ZStack {
        RadialGradient(
          colors: [
            accent.opacity(isBreathing ? 0.16 : 0.10),
            accent.opacity(0.045),
            Color.clear
          ],
          center: .top,
          startRadius: 0,
          endRadius: width * 0.62
        )

        ForEach(0..<4, id: \.self) { index in
          Ellipse()
            .stroke(
              accent.opacity(0.10 - Double(index) * 0.015),
              style: StrokeStyle(lineWidth: 1, dash: [7, 11])
            )
            .frame(
              width: width * (0.36 + CGFloat(index) * 0.22),
              height: height * (0.50 + CGFloat(index) * 0.24)
            )
            .position(x: centerX, y: centerY)
            .scaleEffect(isBreathing ? 1.015 : 0.99)
        }

        ProviderHeroOrbitIcon(systemName: "shippingbox", x: centerX - width * 0.27, y: height * 0.37)
        ProviderHeroOrbitIcon(systemName: "server.rack", x: centerX - width * 0.08, y: height * 0.10)
        ProviderHeroOrbitIcon(systemName: "link", x: centerX + width * 0.26, y: height * 0.26)
        ProviderHeroOrbitIcon(systemName: "arrow.up.doc", x: centerX + width * 0.10, y: height * 0.48)
      }
      .frame(width: width, height: height)
      .onAppear {
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
          isBreathing = true
        }
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

private struct ProviderHeroOrbitIcon: View {
  var systemName: String
  var x: CGFloat
  var y: CGFloat

  var body: some View {
    Image(systemName: systemName)
      .font(.system(size: 16, weight: .medium))
      .foregroundStyle(.secondary.opacity(0.15))
      .position(x: x, y: y)
  }
}

private func providerAccent(for kind: UploadProviderKind) -> Color {
  switch kind {
  case .hereNow:
    return Color(hex: "8E8E93")
  case .imgur:
    return Color(hex: "1BB76E")
  case .amazonS3:
    return Color(hex: "FF9900")
  case .cloudflareR2:
    return Color(hex: "F38020")
  case .googleDrive:
    return Color(hex: "4285F4")
  case .dropbox:
    return Color(hex: "0061FF")
  case .s3Compatible:
    return Color(hex: "8E8E93")
  }
}

struct ProviderLogo: View {
  var kind: UploadProviderKind
  var size: CGFloat
  var preservesBrandMark = false

  var body: some View {
    Group {
      if let assetName, let image = ProviderLogoAsset.image(
        named: assetName,
        fitting: CGSize(width: frameWidth, height: size)
      ) {
        Image(nsImage: image)
          .resizable()
          .interpolation(.high)
          .scaledToFit()
          .frame(width: frameWidth, height: size)
          .clipped()
      } else {
        fallbackLogo
      }
    }
    .frame(width: frameWidth, height: size)
    .accessibilityHidden(true)
  }

  private var frameWidth: CGFloat {
    switch kind {
    case .imgur:
      return size * 1.75
    case .cloudflareR2:
      return size * 1.55
    default:
      return size
    }
  }

  private var assetName: String? {
    switch kind {
    case .hereNow:
      return "here-now"
    case .imgur:
      return "imgur"
    case .amazonS3:
      return "amazon-s3"
    case .cloudflareR2:
      return "cloudflare"
    case .googleDrive:
      return "google-drive"
    case .dropbox:
      return "dropbox"
    case .s3Compatible:
      return nil
    }
  }

  @ViewBuilder
  private var fallbackLogo: some View {
    switch kind {
    case .hereNow:
      HereNowLogo(size: size)
    case .imgur:
      ImgurLogo(size: size, preservesBrandMark: preservesBrandMark)
    case .amazonS3:
      S3Logo(size: size, isAWS: true, preservesBrandMark: preservesBrandMark)
    case .cloudflareR2:
      CloudflareLogo(size: size, preservesBrandMark: preservesBrandMark)
    case .googleDrive:
      GoogleDriveLogo(size: size)
    case .dropbox:
      DropboxLogo(size: size)
    case .s3Compatible:
      S3Logo(size: size, isAWS: false)
    }
  }
}

private enum ProviderLogoAsset {
  static func image(named name: String, fitting displaySize: CGSize) -> NSImage? {
    guard let image = loadImage(named: name) else {
      return nil
    }

    image.size = imageSize(for: image, fitting: displaySize)
    return image
  }

  private static func loadImage(named name: String) -> NSImage? {
    if let url = Bundle.main.url(
      forResource: name,
      withExtension: "png",
      subdirectory: "ProviderLogos"
    ) {
      return NSImage(contentsOf: url)
    }

    guard let url = Bundle.module.url(
      forResource: name,
      withExtension: "png",
      subdirectory: "ProviderLogos"
    ) else {
      return nil
    }

    return NSImage(contentsOf: url)
  }

  private static func imageSize(for image: NSImage, fitting displaySize: CGSize) -> NSSize {
    guard image.size.width > 0, image.size.height > 0 else {
      return NSSize(width: displaySize.width, height: displaySize.height)
    }

    let scale = min(displaySize.width / image.size.width, displaySize.height / image.size.height)
    return NSSize(width: image.size.width * scale, height: image.size.height * scale)
  }
}

private struct LogoTile<Content: View>: View {
  var size: CGFloat
  var fill: Color
  var cornerRatio: CGFloat = 0.23
  @ViewBuilder var content: Content

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: size * cornerRatio, style: .continuous)
        .fill(fill)
        .overlay {
          RoundedRectangle(cornerRadius: size * cornerRatio, style: .continuous)
            .stroke(Color.white.opacity(0.16), lineWidth: max(0.5, size / 72))
        }
        .shadow(color: .black.opacity(size >= 40 ? 0.16 : 0), radius: 14, y: 6)

      content
    }
  }
}

private struct HereNowLogo: View {
  var size: CGFloat

  var body: some View {
    LogoTile(size: size, fill: Color(hex: "111315")) {
      Image(systemName: "cloud")
        .font(.system(size: size * 0.48, weight: .semibold))
        .foregroundStyle(.white)
    }
  }
}

private struct ImgurLogo: View {
  var size: CGFloat
  var preservesBrandMark = false

  var body: some View {
    LogoTile(size: size, fill: Color(hex: "1BB76E")) {
      if size < 32, !preservesBrandMark {
        Text("i")
          .font(.system(size: size * 0.55, weight: .black, design: .rounded))
          .foregroundStyle(.white)
      } else {
        Text("imgur")
          .font(.system(size: size * (size < 32 ? 0.30 : 0.20), weight: .bold, design: .rounded))
          .foregroundStyle(.white)
      }
    }
  }
}

private struct S3Logo: View {
  var size: CGFloat
  var isAWS: Bool
  var preservesBrandMark = false

  var body: some View {
    LogoTile(size: size, fill: isAWS ? Color(hex: "FF9900") : Color.primary.opacity(0.34)) {
      VStack(spacing: isAWS && (size >= 40 || preservesBrandMark) ? -1 : 0) {
        if isAWS && (size >= 40 || preservesBrandMark) {
          Text("AWS")
            .font(.system(size: size * 0.13, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.86))
        }

        Text("S3")
          .font(.system(size: size * (size < 32 ? 0.43 : 0.34), weight: .black, design: .rounded))
          .foregroundStyle(.white)
      }
    }
  }
}

private struct CloudflareLogo: View {
  var size: CGFloat
  var preservesBrandMark = false

  var body: some View {
    LogoTile(size: size, fill: Color(hex: "F38020")) {
      ZStack(alignment: .bottomTrailing) {
        Image(systemName: "cloud.fill")
          .font(.system(size: size * 0.50, weight: .semibold))
          .foregroundStyle(.white)

        if size >= 40 || preservesBrandMark {
          Text("R2")
            .font(.system(size: size * 0.18, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .offset(x: size * 0.04, y: size * 0.04)
        }
      }
      .offset(y: size * 0.02)
    }
  }
}

private struct GoogleDriveLogo: View {
  var size: CGFloat

  var body: some View {
    ZStack {
      GoogleDriveBand(points: [
        CGPoint(x: 0.38, y: 0.08),
        CGPoint(x: 0.58, y: 0.08),
        CGPoint(x: 0.28, y: 0.63),
        CGPoint(x: 0.08, y: 0.63)
      ])
      .fill(Color(hex: "34A853"))

      GoogleDriveBand(points: [
        CGPoint(x: 0.60, y: 0.08),
        CGPoint(x: 0.78, y: 0.42),
        CGPoint(x: 0.96, y: 0.72),
        CGPoint(x: 0.75, y: 0.72),
        CGPoint(x: 0.48, y: 0.22)
      ])
      .fill(Color(hex: "FBBC04"))

      GoogleDriveBand(points: [
        CGPoint(x: 0.08, y: 0.67),
        CGPoint(x: 0.76, y: 0.67),
        CGPoint(x: 0.94, y: 0.94),
        CGPoint(x: 0.25, y: 0.94)
      ])
      .fill(Color(hex: "4285F4"))
    }
    .frame(width: size, height: size)
  }
}

private struct GoogleDriveBand: Shape {
  var points: [CGPoint]

  func path(in rect: CGRect) -> Path {
    var path = Path()
    guard let first = points.first else {
      return path
    }

    path.move(to: CGPoint(x: rect.minX + first.x * rect.width, y: rect.minY + first.y * rect.height))
    for point in points.dropFirst() {
      path.addLine(to: CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height))
    }
    path.closeSubpath()
    return path
  }
}

private struct DropboxLogo: View {
  var size: CGFloat

  var body: some View {
    ZStack {
      ForEach(DropboxDiamondPosition.allCases) { position in
        RoundedRectangle(cornerRadius: size * 0.035, style: .continuous)
          .fill(Color(hex: "0061FF"))
          .frame(width: size * 0.24, height: size * 0.24)
          .rotationEffect(.degrees(45))
          .offset(
            x: position.offset.x * size,
            y: position.offset.y * size
          )
      }
    }
    .frame(width: size, height: size)
  }
}

private enum DropboxDiamondPosition: CaseIterable, Identifiable {
  case topLeft
  case topRight
  case middleLeft
  case middleRight
  case bottom

  var id: Self { self }

  var offset: CGPoint {
    switch self {
    case .topLeft:
      return CGPoint(x: -0.15, y: -0.20)
    case .topRight:
      return CGPoint(x: 0.15, y: -0.20)
    case .middleLeft:
      return CGPoint(x: -0.30, y: 0.06)
    case .middleRight:
      return CGPoint(x: 0.30, y: 0.06)
    case .bottom:
      return CGPoint(x: 0, y: 0.28)
    }
  }
}

private struct ProviderSetupGuide: View {
  var guide: ProviderGuide
  @Binding var isExpanded: Bool

  var body: some View {
    VStack(spacing: 0) {
      Button {
        withAnimation(.easeOut(duration: 0.15)) {
          isExpanded.toggle()
        }
      } label: {
        HStack(spacing: 8) {
          Image(systemName: "sparkles")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)

          Text("Setup guide")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)

          Spacer()

          Image(systemName: "chevron.down")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .rotationEffect(.degrees(isExpanded ? 0 : -90))
        }
        .padding(12)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      if isExpanded {
        SettingsDivider()

        VStack(alignment: .leading, spacing: 12) {
          Text(guide.intro)
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(.secondary)

          VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(guide.steps.enumerated()), id: \.offset) { index, step in
              HStack(alignment: .top, spacing: 8) {
                Text("\(index + 1)")
                  .font(.system(size: 11, weight: .semibold))
                  .foregroundStyle(.secondary)
                  .frame(width: 18, height: 18)
                  .background(SettingsStyle.control, in: Circle())

                Text(step)
                  .font(.system(size: 12, weight: .regular))
                  .foregroundStyle(.primary)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }
          }

          if !guide.links.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
              Text("Useful links")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

              ForEach(guide.links) { link in
                if let url = URL(string: link.url) {
                  Link(destination: url) {
                    HStack(spacing: 6) {
                      Text(link.title)
                        .font(.system(size: 12, weight: .medium))
                      Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .semibold))
                    }
                  }
                }
              }
            }
          }
        }
        .padding(12)
        .transition(.opacity)
      }
    }
    .background(SettingsStyle.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .stroke(SettingsStyle.border, lineWidth: 0.5)
    }
  }
}

private struct SettingsSection<Content: View>: View {
  var title: String?
  @ViewBuilder var content: Content

  init(title: String? = nil, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let title {
        Text(title)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.primary)
          .padding(.horizontal, 12)
      }

      VStack(spacing: 0) {
        content
      }
      .background(SettingsStyle.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .stroke(SettingsStyle.border, lineWidth: 0.5)
      }
    }
  }
}

private struct SettingsDivider: View {
  var body: some View {
    Rectangle()
      .fill(SettingsStyle.separator)
      .frame(height: 1)
      .padding(.horizontal, 12)
  }
}

private struct SettingsRow<Right: View>: View {
  var title: String
  var description: String?
  var controlAlignment: Alignment
  @ViewBuilder var right: Right

  init(
    title: String,
    description: String? = nil,
    controlAlignment: Alignment = .leading,
    @ViewBuilder right: () -> Right
  ) {
    self.title = title
    self.description = description
    self.controlAlignment = controlAlignment
    self.right = right()
  }

  var body: some View {
    HStack(alignment: description == nil ? .center : .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.system(size: 13, weight: .regular))
          .foregroundStyle(.primary)

        if let description {
          Text(description)
            .font(.system(size: 11, weight: .regular))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      right
        .frame(width: SettingsStyle.fieldWidth, alignment: controlAlignment)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 9)
    .frame(minHeight: 46)
  }
}

private struct SettingsTextFieldRow: View {
  var title: String
  var placeholder: String
  @Binding var text: String

  init(_ title: String, text: Binding<String>, placeholder: String = "") {
    self.title = title
    self.placeholder = placeholder
    self._text = text
  }

  init(title: String, text: Binding<String>, placeholder: String = "") {
    self.title = title
    self.placeholder = placeholder
    self._text = text
  }

  var body: some View {
    SettingsRow(title: title) {
      TextField(placeholder, text: $text)
        .textFieldStyle(.plain)
        .font(.system(size: 12, weight: .regular))
        .padding(.horizontal, 8)
        .frame(width: SettingsStyle.fieldWidth, height: 28)
        .background(SettingsStyle.field, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 7, style: .continuous)
            .stroke(SettingsStyle.fieldBorder, lineWidth: 0.5)
        }
    }
  }
}

private struct SettingsSecureFieldRow: View {
  var title: String
  var placeholder: String
  @Binding var text: String

  init(_ title: String, text: Binding<String>, placeholder: String = "") {
    self.title = title
    self.placeholder = placeholder
    self._text = text
  }

  var body: some View {
    SettingsRow(title: title) {
      SecureField(placeholder, text: $text)
        .textFieldStyle(.plain)
        .font(.system(size: 12, weight: .regular))
        .padding(.horizontal, 8)
        .frame(width: SettingsStyle.fieldWidth, height: 28)
        .background(SettingsStyle.field, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 7, style: .continuous)
            .stroke(SettingsStyle.fieldBorder, lineWidth: 0.5)
        }
    }
  }
}

private struct SettingsToggleRow: View {
  var title: String
  @Binding var isOn: Bool

  var body: some View {
    SettingsRow(title: title, controlAlignment: .trailing) {
      Toggle("", isOn: $isOn)
        .labelsHidden()
    }
  }
}

private struct SettingsPickerRow<Selection: Hashable, Content: View>: View {
  var title: String
  @Binding var selection: Selection
  @ViewBuilder var content: Content

  init(title: String, selection: Binding<Selection>, @ViewBuilder content: () -> Content) {
    self.title = title
    self._selection = selection
    self.content = content()
  }

  var body: some View {
    SettingsRow(title: title) {
      Picker("", selection: $selection) {
        content
      }
      .labelsHidden()
      .pickerStyle(.menu)
      .controlSize(.small)
      .fixedSize()
    }
  }
}
