import SwiftUI
import MapKit

struct ContentView: View {

    @StateObject private var viewModel = MainViewModel()
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var searchText: String = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        Group {
            if viewModel.hasArrived {
                arrivedView
            } else if viewModel.isNavigating {
                navigatingView
            } else {
                setupView
            }
        }
        .animation(.easeInOut(duration: 0.5), value: viewModel.isNavigating)
        .animation(.easeInOut(duration: 0.5), value: viewModel.hasArrived)
        .alert("エラー", isPresented: $viewModel.showAlert) {
            Button("OK") {}
        } message: {
            Text(viewModel.alertMessage)
        }
    }

    // MARK: - ① 到着画面

    private var arrivedView: some View {
        ZStack {
            Color.green.opacity(0.9).ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(.white)
                Text("到着！")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("お疲れ様でした 🎉")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Button {
                    viewModel.stopNavigation()
                } label: {
                    Text("閉じる")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white.opacity(0.25))
                        .cornerRadius(16)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }

    // MARK: - ② ナビ中画面（信号機UI）

    private var navigatingView: some View {
        ZStack {
            // 全画面ステータスカラー
            statusBackgroundColor
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: viewModel.paceStatus)

            VStack(spacing: 0) {

                // ── ステータスエリア（上60%）
                VStack(spacing: 8) {
                    Spacer()

                    // アイコン
                    Image(systemName: statusIconName)
                        .font(.system(size: 64, weight: .thin))
                        .foregroundStyle(.white.opacity(0.9))

                    // メッセージ
                    Text(viewModel.paceStatus.message)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.paceStatus)

                    // 残り時間（最大強調）
                    Text(remainingTimeText)
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    // 残り距離
                    Text(formattedDistance(viewModel.remainingDistance))
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))

                    Spacer()
                }
                .frame(maxHeight: .infinity)

                // ── 地図エリア（下40% サブ要素）
                VStack(spacing: 12) {
                    miniMap
                        .frame(height: 180)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                        .padding(.horizontal, 20)

                    // 停止ボタン
                    Button {
                        viewModel.stopNavigation()
                    } label: {
                        Label("停止", systemImage: "stop.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.black.opacity(0.25))
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
    }

    // ミニマップ（ナビ中のサブ表示）
    private var miniMap: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()
            if let destination = viewModel.destination {
                Annotation("", coordinate: destination) {
                    ZStack {
                        Circle().fill(Color.red).frame(width: 28, height: 28)
                        Image(systemName: "flag.fill").foregroundStyle(.white).font(.system(size: 12))
                    }
                }
            }
            if let route = viewModel.routeManager.route {
                MapPolyline(route.polyline).stroke(Color.white.opacity(0.9), lineWidth: 4)
            }
        }
        .mapControls { }                        // コントロール非表示
        .allowsHitTesting(false)                // タップ無効（サブ表示のため）
    }

    // MARK: - ③ 設定画面（ナビ開始前）

    private var setupView: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // 地図（目的地タップ設定）
                    MapReader { proxy in
                        Map(position: $cameraPosition) {
                            UserAnnotation()
                            if let dest = viewModel.destination {
                                Annotation("目的地", coordinate: dest) {
                                    ZStack {
                                        Circle().fill(Color.red).frame(width: 32, height: 32)
                                        Image(systemName: "flag.fill").foregroundStyle(.white).font(.system(size: 14))
                                    }
                                }
                            }
                        }
                        .mapControls {
                            MapUserLocationButton()
                            MapCompass()
                        }
                        .overlay(alignment: .topLeading) {
                            Label("地図をタップして目的地を設定", systemImage: "mappin.and.ellipse")
                                .font(.caption)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                                .padding(.top, 12).padding(.leading, 12)
                        }
                        .onTapGesture { loc in
                            if let coord = proxy.convert(loc, from: .local) {
                                viewModel.destination = coord
                                searchText = ""
                                searchResults = []
                            }
                        }
                    }
                    .frame(height: 260)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                    .padding(.horizontal, 16)

                    // 設定カード
                    VStack(spacing: 12) {

                        // 検索バー
                        VStack(spacing: 0) {
                            HStack {
                                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                                TextField("目的地を検索（例: 渋谷駅）", text: $searchText)
                                    .submitLabel(.search)
                                    .onSubmit { performSearch(query: searchText) }
                                    .onChange(of: searchText) { _, v in performSearch(query: v) }
                                if !searchText.isEmpty {
                                    Button { searchText = ""; searchResults = [] } label: {
                                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(12)

                            if !searchResults.isEmpty {
                                Divider()
                                ForEach(searchResults, id: \.self) { item in
                                    Button {
                                        selectSearchResult(item)
                                    } label: {
                                        HStack {
                                            Image(systemName: "mappin.circle.fill").foregroundStyle(.red)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.name ?? "不明な場所").font(.subheadline).foregroundStyle(.primary)
                                                if let addr = item.placemark.title {
                                                    Text(addr).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                                }
                                            }
                                            Spacer()
                                        }
                                        .padding(.horizontal, 12).padding(.vertical, 8)
                                    }
                                    Divider().padding(.leading, 40)
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(14)
                        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)

                        // 目的地状態
                        if viewModel.destination != nil {
                            Label("目的地が設定されました", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                        }

                        // 到着希望時刻
                        HStack {
                            Label("到着希望時刻", systemImage: "clock")
                                .font(.subheadline)
                            Spacer()
                            DatePicker("", selection: $viewModel.arrivalTime, in: Date()..., displayedComponents: [.hourAndMinute, .date])
                                .datePickerStyle(.compact)
                                .environment(\.locale, Locale(identifier: "ja_JP"))
                        }
                        .padding(14)
                        .background(Color(.systemBackground))
                        .cornerRadius(14)
                        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)

                        // スタートボタン
                        if viewModel.destination != nil {
                            Button {
                                viewModel.startNavigation()
                            } label: {
                                Group {
                                    if viewModel.routeManager.isLoading {
                                        HStack { ProgressView().tint(.white); Text("経路を取得中...") }
                                    } else {
                                        Label("ナビ開始", systemImage: "figure.walk")
                                    }
                                }
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.blue)
                                .cornerRadius(16)
                            }
                            .disabled(viewModel.routeManager.isLoading)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("WalkPacer")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - 検索ロジック

    private func performSearch(query: String) {
        searchTask?.cancel()
        guard !query.isEmpty else { searchResults = []; return }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            let response = try? await MKLocalSearch(request: request).start()
            await MainActor.run { searchResults = response?.mapItems ?? [] }
        }
    }

    private func selectSearchResult(_ item: MKMapItem) {
        viewModel.destination = item.placemark.coordinate
        cameraPosition = .region(MKCoordinateRegion(
            center: item.placemark.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
        searchText = item.name ?? ""
        searchResults = []
    }

    // MARK: - ユーティリティ

    private var remainingTimeText: String {
        let m = viewModel.remainingMinutes
        if m <= 0 { return "0分" }
        if m >= 60 { return "\(m / 60)時間\(m % 60)分" }
        return "\(m)分"
    }

    private func formattedDistance(_ m: Double) -> String {
        m >= 1000 ? String(format: "%.1f km", m / 1000) : String(format: "%.0f m", m)
    }

    private var statusBackgroundColor: Color {
        switch viewModel.paceStatus {
        case .onPace:                  return Color(red: 0.15, green: 0.72, blue: 0.35)
        case .slightlyBehind:          return Color(red: 0.98, green: 0.73, blue: 0.01)
        case .behind, .overdue:        return Color(red: 0.93, green: 0.22, blue: 0.22)
        }
    }

    private var statusIconName: String {
        switch viewModel.paceStatus {
        case .onPace:                  return "checkmark.circle"
        case .slightlyBehind:          return "exclamationmark.circle"
        case .behind, .overdue:        return "xmark.circle"
        }
    }
}

#Preview {
    ContentView()
}
