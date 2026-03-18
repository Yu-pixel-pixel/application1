import SwiftUI
import MapKit

struct ContentView: View {

    @StateObject private var viewModel = MainViewModel()
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // MARK: - 上半分: マップエリア
                mapArea
                    .frame(height: geometry.size.height * 0.55)

                // MARK: - 下半分: ペース情報エリア
                paceInfoArea
                    .frame(height: geometry.size.height * 0.45)
            }
        }
        .ignoresSafeArea(edges: .top)
        .alert("エラー", isPresented: $viewModel.showAlert) {
            Button("OK") {}
        } message: {
            Text(viewModel.alertMessage)
        }
    }

    // MARK: - マップエリア

    private var mapArea: some View {
        Map(position: $cameraPosition) {
            // 現在地表示
            UserAnnotation()

            // 目的地ピン
            if let destination = viewModel.destination {
                Annotation("目的地", coordinate: destination) {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 32, height: 32)
                        Image(systemName: "flag.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 14))
                    }
                }
            }

            // ルートポリライン
            if let route = viewModel.routeManager.route {
                MapPolyline(route.polyline)
                    .stroke(Color.blue, lineWidth: 4)
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .onMapCameraChange { context in
            // カメラ変更時は何もしない（自動追跡のみ）
            _ = context
        }
        .overlay(alignment: .topLeading) {
            if !viewModel.isNavigating {
                Text("地図をタップして目的地を設定")
                    .font(.caption)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .padding(12)
            }
        }
        .gesture(
            SpatialTapGesture()
                .onEnded { value in
                    guard !viewModel.isNavigating else { return }
                    // タップ位置をCoordinateに変換するためMapReaderを使う
                }
        )
        // MapReader でタップ位置→座標変換
        .mapReader { proxy in
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { location in
                    guard !viewModel.isNavigating else { return }
                    if let coordinate = proxy.convert(location, from: .local) {
                        viewModel.destination = coordinate
                    }
                }
        }
    }

    // MARK: - ペース情報エリア

    private var paceInfoArea: some View {
        ZStack {
            // 背景色
            paceBackgroundColor
                .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 12) {
                if viewModel.isNavigating {
                    navigatingInfoView
                } else {
                    setupView
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    // MARK: - ナビ中ビュー

    private var navigatingInfoView: some View {
        VStack(spacing: 10) {
            // ペースメッセージ
            Text(viewModel.paceStatus.message)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(paceTextColor)
                .multilineTextAlignment(.center)

            Divider()
                .background(paceTextColor.opacity(0.4))

            // 残り距離
            HStack {
                Image(systemName: "figure.walk")
                Text("目的地まであと \(Int(viewModel.remainingDistance)) m")
                    .font(.headline)
            }
            .foregroundColor(paceTextColor)

            // 到着設定時刻
            HStack {
                Image(systemName: "clock")
                Text("到着設定時刻: \(viewModel.arrivalTime, style: .time)")
                    .font(.subheadline)
            }
            .foregroundColor(paceTextColor.opacity(0.9))

            // 速度情報
            HStack {
                Image(systemName: "speedometer")
                Text(String(format: "必要速度: %.1f km/h  ／  現在速度: %.1f km/h",
                            viewModel.requiredSpeed * 3.6,
                            viewModel.currentSpeed * 3.6))
                    .font(.subheadline)
            }
            .foregroundColor(paceTextColor.opacity(0.9))

            Spacer()

            // 停止ボタン
            Button {
                viewModel.stopNavigation()
            } label: {
                Label("停止", systemImage: "stop.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(12)
            }
        }
    }

    // MARK: - 設定ビュー（ナビ開始前）

    private var setupView: some View {
        VStack(spacing: 14) {
            // 目的地設定状態
            if viewModel.destination != nil {
                Label("目的地が設定されました", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.subheadline)
            } else {
                Label("地図をタップして目的地を設定してください", systemImage: "mappin.circle")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
            }

            // 到着希望時刻
            DatePicker(
                "到着希望時刻",
                selection: $viewModel.arrivalTime,
                in: Date()...,
                displayedComponents: [.hourAndMinute, .date]
            )
            .datePickerStyle(.compact)
            .environment(\.locale, Locale(identifier: "ja_JP"))

            Spacer()

            // スタートボタン（目的地設定済みの場合のみ表示）
            if viewModel.destination != nil {
                Button {
                    viewModel.startNavigation()
                } label: {
                    if viewModel.routeManager.isLoading {
                        HStack {
                            ProgressView()
                                .tint(.white)
                            Text("経路を取得中...")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    } else {
                        Label("スタート", systemImage: "play.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
                .disabled(viewModel.routeManager.isLoading)
            }
        }
    }

    // MARK: - ヘルパー

    private var paceBackgroundColor: Color {
        guard viewModel.isNavigating else { return Color(.systemGray6) }
        switch viewModel.paceStatus {
        case .onPace:         return Color.blue.opacity(0.85)
        case .slightlyBehind: return Color.yellow.opacity(0.85)
        case .behind:         return Color.red.opacity(0.85)
        case .overdue:        return Color.red.opacity(0.85)
        }
    }

    private var paceTextColor: Color {
        switch viewModel.paceStatus {
        case .onPace:         return .white
        case .slightlyBehind: return Color(.darkText)
        case .behind:         return .white
        case .overdue:        return .white
        }
    }
}

#Preview {
    ContentView()
}
