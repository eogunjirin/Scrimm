import SwiftUI

struct ContentView: View {
    @State private var urlString: String = ""
    @State private var destinationURL: URL?
    @State private var videoPlayerURL: URL?

    var body: some View {
        VStack {
            HStack(spacing: 12) {
                TextField("", text: $urlString, prompt: Text("Enter URL to Scrape...").foregroundColor(.gray))
                    .padding(10)
                    .background(Color(white: 0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8).stroke(Color(white: 0.2), lineWidth: 1)
                    )
                    .font(.body)
                    .foregroundColor(.white)

                Button("Go") {
                    if let url = URL(string: urlString), urlString.lowercased().hasPrefix("http") {
                        destinationURL = url
                    }
                }
                .keyboardShortcut(.defaultAction)
                .font(.body.bold())
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.05).ignoresSafeArea())
        .preferredColorScheme(.dark)
        
        // SHEET 1: The Interactive Web Browser
        .sheet(item: $destinationURL) { url in
            WebView(url: url) { foundVideoURL in
                self.videoPlayerURL = foundVideoURL
                self.destinationURL = nil
            }
            // --- THIS IS THE FIX ---
            // Give the sheet a proper, usable size.
            .frame(minWidth: 800, idealWidth: 1280, minHeight: 600, idealHeight: 720)
        }
        
        // SHEET 2: The Final Video Player
        .sheet(item: $videoPlayerURL) { url in
            VideoPlayerView(videoURL: url)
                .frame(minWidth: 800, minHeight: 450)
        }
    }
}

extension URL: Identifiable {
    public var id: String { self.absoluteString }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
