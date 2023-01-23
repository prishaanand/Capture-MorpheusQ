import SwiftUI
import Combine

private struct Blur: UIViewRepresentable {
    let style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

struct ContentView: View {
    @State private var arController: ARViewController?
    @State private var capture = false
    private var buttonLabel: String {
        capture ?  "Retake Capture" : "Take Capture"
    }
    
    var body: some View {        
        return ZStack(alignment: .bottom) {
            ARContainer(ref: { ref in
                DispatchQueue.main.async {
                    self.arController = ref
                }
            })
                .edgesIgnoringSafeArea(.top)
            
            HStack {
                
                //implement capture feature
                Button(action: {
                    if capture {
                        arController!.retake()
                    } else {
                        arController!.capture()
                    }
                    capture.toggle()
                }, label: {
                    Text(buttonLabel)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(Color.white)
                })
            }
        }
        .statusBar(hidden: true)
    }
}
