import SwiftUI

// --- HELPER VIEW FOR TRANSLUCENT BACKGROUND (UNCHANGED) ---
struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .underWindowBackground
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// --- UPDATED CONTENT VIEW WITH ZSTACK ---
struct ContentView: View {
    // --- YOUR LOGIC - UNCHANGED ---
    @State private var urlString: String = ""
    @State private var destinationURL: URL?
    @State private var videoPlayerURL: URL?

    var body: some View {
        // Use a ZStack to layer the background behind the content
        ZStack {
            // Layer 1: The background. It will now fill the entire space.
            VisualEffectView()
                .ignoresSafeArea()

            // Layer 2: Your content, placed on top of the background.
            VStack {
                // Spacer to push the content down from the top edge
                Spacer()
                
                // The content block (input field and button)
                HStack(spacing: 10) {
                    TextField("Enter URL", text: $urlString)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 14))
                        .padding(12)
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(8)
                        .foregroundColor(.white)

                    Button("Go") {
                        // --- YOUR LOGIC - UNCHANGED ---
                        let trimmedString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedString.isEmpty else { return }
                        var finalUrlString = trimmedString
                        if !trimmedString.lowercased().hasPrefix("http://") && !trimmedString.lowercased().hasPrefix("https://") {
                            finalUrlString = "https://" + trimmedString
                        }
                        if let url = URL(string: finalUrlString), url.host != nil {
                            destinationURL = url
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .buttonStyle(PlainButtonStyle())
                }
                .frame(maxWidth: 500)
                .padding()

                // Two spacers at the bottom to push the content block slightly *above* center
                Spacer()
                Spacer()
            }
        }
        // Apply window-level modifiers to the ZStack
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.dark)
        
        // --- YOUR SHEET LOGIC - UNCHANGED ---
        .sheet(item: $destinationURL) { url in
            WebView(url: url) { foundVideoURL in
                self.videoPlayerURL = foundVideoURL
                self.destinationURL = nil
            }
            .frame(minWidth: 800, idealWidth: 1280, minHeight: 600, idealHeight: 720)
        }
        .sheet(item: $videoPlayerURL) { url in
            VideoPlayerView(videoURL: url)
                .frame(minWidth: 800, minHeight: 450)
        }
    }
}

// Your existing extension and preview are fine
extension URL: Identifiable {
    public var id: String { self.absoluteString }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
