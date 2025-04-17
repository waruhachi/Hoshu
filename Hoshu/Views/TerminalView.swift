//
//  TerminalView.swift
//  Hoshu
//
//  Created by Waruha on 4/16/25.
//

import FluidGradient
import SwiftUI

struct TerminalView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var outputText: String
    @Binding var isProcessing: Bool
    var retroStyle: Bool

    // State for blinking cursor and screen flicker
    @State private var showCursor = false
    @State private var flickerOpacity = 0.0
    @State private var grainPhase = 0.0  // For animating grain

    // State for character-by-character typing effect
    @State private var displayedText = ""
    @State private var currentCharIndex = 0
    @State private var isTyping = false

    // Typing speed configuration (seconds per character)
    private let typingSpeed: Double = 0.07
    private let typingVariance: Double = 0.03  // Random variance to make typing look more natural

    init(outputText: Binding<String>, isProcessing: Binding<Bool>, retroStyle: Bool = false) {
        self._outputText = outputText
        self._isProcessing = isProcessing
        self.retroStyle = retroStyle

        // Set navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = .white
    }

    // Timer for blinking cursor
    private let timer = Timer.publish(every: 0.7, on: .main, in: .common).autoconnect()

    // Random flicker timer (less frequent)
    private let flickerTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    // Grain animation timer
    private let grainTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    // Define retro green color
    private var textColor: Color {
        retroStyle ? Color(red: 0, green: 0.85, blue: 0.3) : .white
    }

    // CRT glow effect for the text
    private var textEffect: some ViewModifier {
        struct GlowEffect: ViewModifier {
            let color: Color
            let radius: CGFloat

            func body(content: Content) -> some View {
                content
                    .shadow(color: color.opacity(0.7), radius: radius, x: 0, y: 0)
                    .shadow(color: color.opacity(0.3), radius: radius * 2, x: 0, y: 0)
            }
        }

        return retroStyle
            ? GlowEffect(color: Color(red: 0, green: 0.85, blue: 0.3), radius: 1.5)
            : GlowEffect(color: .clear, radius: 0)
    }

    // Optional scanline effect for retro style
    private var retroBackground: some View {
        ZStack {
            Color.black
            if retroStyle {
                GeometryReader { geometry in
                    VStack(spacing: 1) {
                        ForEach(0..<Int(geometry.size.height / 2), id: \.self) { _ in
                            Rectangle()
                                .fill(Color.black.opacity(0.25))
                                .frame(height: 1)
                        }
                    }
                    .blendMode(.lighten)
                }
                // Add subtle noise texture overlay
                Rectangle()
                    .fill(Color.white.opacity(0.03))
                    .blendMode(.overlay)
            }
        }
    }

    // Function to type characters one by one
    private func typeNextCharacter() {
        guard currentCharIndex < outputText.count else {
            isTyping = false
            return
        }

        let index = outputText.index(outputText.startIndex, offsetBy: currentCharIndex)
        displayedText += String(outputText[index])
        currentCharIndex += 1

        // If there are more characters to type, schedule the next one with a slight random delay
        if currentCharIndex < outputText.count {
            let randomDelay = typingSpeed + Double.random(in: -typingVariance...typingVariance)
            DispatchQueue.main.asyncAfter(deadline: .now() + randomDelay) {
                typeNextCharacter()
            }
        } else {
            isTyping = false
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                retroBackground
                    .ignoresSafeArea()

                VStack {
                    ScrollView {
                        ScrollViewReader { scrollView in
                            VStack(alignment: .leading) {
                                Text(
                                    displayedText
                                        + (retroStyle && (isProcessing || isTyping)
                                            ? (showCursor ? "█" : "") : "")
                                )
                                .font(
                                    retroStyle
                                        ? .system(size: 15, weight: .medium, design: .monospaced)
                                        : .system(.footnote, design: .monospaced)
                                )
                                .lineSpacing(retroStyle ? 3 : 1)  // Increased line spacing for retro look
                                .foregroundColor(textColor)
                                .modifier(textEffect)
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .id("outputEnd")
                                .onReceive(timer) { _ in
                                    if retroStyle && (isProcessing || isTyping) {
                                        showCursor.toggle()
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .onReceive(
                                NotificationCenter.default.publisher(
                                    for: Notification.Name("terminalOutputUpdate"))
                            ) { notification in
                                if let newText = notification.object as? String {
                                    // Only update for new content
                                    if newText != outputText {
                                        let oldTextCount = outputText.count
                                        outputText = newText

                                        // Only animate the new part
                                        currentCharIndex = oldTextCount
                                        isTyping = true
                                        typeNextCharacter()
                                    }

                                    withAnimation {
                                        scrollView.scrollTo("outputEnd", anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }

                    if isProcessing {
                        HStack {}
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.vertical)
                .onAppear {
                    restartTypingAnimation()
                }
                .onChange(of: outputText) { newValue in
                    if newValue != displayedText && !isTyping {
                        // Only animate the new part
                        if displayedText.isEmpty {
                            restartTypingAnimation()
                        } else {
                            let commonPrefix = newValue.commonPrefix(with: displayedText)
                            currentCharIndex = commonPrefix.count
                            isTyping = true
                            typeNextCharacter()
                        }
                    }
                }

                // Apply CRT curve effect when in retro mode
                if retroStyle {
                    CRTCurveEffect()
                        .blendMode(.overlay)
                        .ignoresSafeArea()

                    // Film grain effect
                    FilmGrainView(phase: grainPhase)
                        .blendMode(.softLight)
                        .opacity(0.5)
                        .ignoresSafeArea()
                        .onReceive(grainTimer) { _ in
                            // Animate grain by changing the phase
                            withAnimation(.linear(duration: 0.05)) {
                                grainPhase = Double.random(in: 0...100)
                            }
                        }

                    // Occasional screen flicker effect
                    Rectangle()
                        .fill(Color.white)
                        .blendMode(.overlay)
                        .opacity(flickerOpacity)
                        .ignoresSafeArea()
                        .onReceive(flickerTimer) { _ in
                            if retroStyle {
                                // Only flicker occasionally (1 in 3 chance)
                                if Int.random(in: 0...2) == 0 {
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        flickerOpacity = Double.random(in: 0.01...0.05)

                                        // Reset the flicker after a brief moment
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                            withAnimation(.easeInOut(duration: 0.1)) {
                                                flickerOpacity = 0.0
                                            }
                                        }
                                    }
                                }
                            }
                        }
                }
            }
            .navigationBarTitle("Script Output", displayMode: .inline)
            .navigationBarItems(
                trailing: Button(action: {
                    if !isProcessing && !isTyping {
                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
                    Text("Done")
                        .foregroundColor((isProcessing || isTyping) ? .gray : .white)
                }
                .disabled(isProcessing || isTyping)
            )
        }
    }

    // Function to restart the typing animation
    private func restartTypingAnimation() {
        isTyping = true
        displayedText = ""
        currentCharIndex = 0
        typeNextCharacter()
    }

    // CRT screen curve effect
    struct CRTCurveEffect: View {
        var body: some View {
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height

                ZStack {
                    // Create vignette effect (darker corners)
                    RadialGradient(
                        gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.3)]),
                        center: .center,
                        startRadius: min(width, height) * 0.3,
                        endRadius: min(width, height) * 0.7
                    )

                    // Add subtle screen curve distortion
                    Rectangle()
                        .fill(Color.clear)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.green.opacity(0.05), Color.clear]
                                ),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
        }
    }

    // Film grain effect
    struct FilmGrainView: View {
        var phase: Double

        var body: some View {
            GeometryReader { geometry in
                // Generate a grid of random noise dots
                ZStack {
                    // Create a base noise texture
                    Color.white
                        .opacity(0.02)

                    // Create a grid of random noise dots
                    ForEach(0..<40, id: \.self) { row in
                        ForEach(0..<40, id: \.self) { col in
                            let randomX =
                                CGFloat(col * Int(geometry.size.width) / 40)
                                + CGFloat.random(in: -3...3)
                            let randomY =
                                CGFloat(row * Int(geometry.size.height) / 40)
                                + CGFloat.random(in: -3...3)
                            let seed = Int(phase) &+ row &* col
                            let randomOpacity = seed % 5 == 0 ? Double.random(in: 0.1...0.3) : 0.0
                            let size = Double.random(in: 0.5...1.5)

                            Circle()
                                .fill(Color.white)
                                .frame(width: size, height: size)
                                .position(x: randomX, y: randomY)
                                .opacity(randomOpacity)
                        }
                    }

                    // Add some larger bright specs for a more authentic look
                    ForEach(0..<5, id: \.self) { i in
                        let randomX = CGFloat.random(in: 0...geometry.size.width)
                        let randomY = CGFloat.random(in: 0...geometry.size.height)
                        let randomSize = Double.random(in: 0.3...0.8)
                        let randomOpacity = Double.random(in: 0.1...0.4)

                        Circle()
                            .fill(Color.white)
                            .frame(width: randomSize, height: randomSize)
                            .position(x: randomX, y: randomY)
                            .opacity(randomOpacity)
                    }
                }
            }
        }
    }
}

struct TerminalView_Previews: PreviewProvider {
    @State static var previewText =
        "$ rootless-patcher\nConverting package...\nExtracting control...\nModifying architecture...\nRebuilding package...\nScript complete!"
    @State static var isProcessing = true

    static var previews: some View {
        Group {
            TerminalView(outputText: $previewText, isProcessing: $isProcessing, retroStyle: false)
                .previewDisplayName("Standard Terminal")

            TerminalView(outputText: $previewText, isProcessing: $isProcessing, retroStyle: true)
                .previewDisplayName("Retro Terminal")
        }
    }
}
