import SwiftUI
import MapKit

struct ContentView: View {

    @StateObject private var viewModel = MainViewModel()
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    // 目的地検索
    @State private var searchText: String = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                mapArea
                    .frame(height: geometry.size.height * 0.55)
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
        MapReader { proxy in
            Map(position: $cameraPosition) {
                UserAnnotation()

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
            .overlay(alignment: .topLeading) {
                if !viewModel.isNavigating {
                    Label("地図をタップして目的地を設定", systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .padding(.top, 56)
                        .padding(.leading, 12)
                }
            }
            .onTapGesture { location in
                guard !viewModel.isNavigating else { return }
                if let coordinate = proxy.convert(location, from: .local) {
                    viewModel.destination = coordinate
                    searchText = ""
                    searchResults = []
                }
            }
        }
    }

    // MARK: - ペース情報エリア

    private var paceInfoArea: some View {
        ZStack {
            paceBackgroundColor
                .ignoresSafeArea(edges: .bottom)
                .animation(.easeInOut(duration: 0.4), value: viewModel.paceStatus)

            VStack(spacing: 0) {
                if viewModel.isNavigating {
                    navigatingInfoView
                } else {
                    setupView
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
    }

    // MARK: - ナビ中ビュー

    private var navigatingInfoView: some View {
        VStack(spacing: 10) {
            Text(viewModel.paceStatus.message)
                .font(.title2.bold())
                .foregroundColor(paceTextColor)
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.3), value: viewModel.paceStatus)

            progressBar

            HStack(spacing: 0) {
                infoCell(
                    icon: "figure.walk",
                    label: "残り距離",
                    value: formattedDistance(viewModel.remainingDistance)
                )
                Divider()
                    .frame(height: 40)
                    .background(paceTextColor.opacity(0.3))
                infoCell(
                    icon: "clock",
                    label: "到着設定",
                    value: viewModel.arrivalTime.formatted(date: .omitted, time: .shortened)
                )
            }
            .background(paceTextColor.opacity(0.1))
            .cornerRadius(10)

            HStack(spacing: 0) {
                speedCell(
                    label: "必要速度",
                    value: String(format: "%.1f", viewModel.requiredSpeed * 3.6),
                    unit: "km/h",
                    icon: "arrow.up.circle"
                )
                Divider()
                    .frame(height: 40)
                    .background(paceTextColor.opacity(0.3))
                speedCell(
                    label: "現在速度",
                    value: String(format: "%.1f", viewModel.currentSpeed * 3.6),
                    unit: "km/h",
                    icon: "speedometer"
                )
            }
            .background(paceTextColor.opacity(0.1))
            .cornerRadius(10)

            Spacer()

            Button {
                viewModel.stopNavigation()
            } label: {
                Label("停止", systemImage: "stop.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.black.opacity(0.35))
                    .cornerRadius(14)
            }
        }
    }

    // MARK: - 進捗バー

    private var progressBar: some View {
        let total = viewModel.routeManager.totalDistance
        let walked = total - viewModel.remainingDistance
        let progress = total > 0 ? min(walked / total, 1.0) : 0.0

        return VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(paceTextColor.opacity(0.2))
                    Capsule()
                        .fill(paceTextColor.opacity(0.85))
                        .frame(width: geo.size.width * progress)
                        .animation(.easeInOut(duration: 0.5), value: progress)
                }
            }
            .frame(height: 6)

            HStack {
                Text("出発")
                Spacer()
                Text(String(format: "%.0f%%", progress * 100))
                Spacer()
                Text("目的地")
            }
            .font(.caption2)
            .foregroundColor(paceTextColor.opacity(0.7))
        }
    }

    // MARK: - 設定ビュー（ナビ開始前）

    private var setupView: some View {
        VStack(spacing: 12) {

            // 検索バー
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("目的地を検索（例: 渋谷駅）", text: $searchText)
                    .submitLabel(.search)
                    .onSubmit { performSearch(query: searchText) }
                    .onChange(of: searchText) { _, newValue in
                        performSearch(query: newValue)
                    }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)

            // 検索結果リスト
            if !searchResults.isEmpty {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(searchResults, id: \.self) { item in
                            Button {
                                selectSearchResult(item)
                            } label: {
                                HStack {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundColor(.red)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name ?? "不明な場所")
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        if let address = item.placemark.title {
                                            Text(address)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }
                            Divider().padding(.leading, 40)
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                }
                .frame(maxHeight: 160)
            } else {
                // 検索結果がない場合は目的地設定状態を表示
                if viewModel.destination != nil {
                    Label("目的地が設定されました", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.subheadline)
                } else {
                    Label("地図をタップするか上で検索してください", systemImage: "mappin.circle")
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
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

            if viewModel.destination != nil {
                Button {
                    viewModel.startNavigation()
                } label: {
                    Group {
                        if viewModel.routeManager.isLoading {
                            HStack {
                                ProgressView().tint(.white)
                                Text("経路を取得中...")
                            }
                        } else {
                            Label("スタート", systemImage: "play.fill")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(14)
                }
                .disabled(viewModel.routeManager.isLoading)
            }
        }
    }

    // MARK: - 検索ロジック

    private func performSearch(query: String) {
        searchTask?.cancel()
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        searchTask = Task {
            // 0.4秒待って連続入力中は検索しない
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }

            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            let search = MKLocalSearch(request: request)
            let response = try? await search.start()

            await MainActor.run {
                searchResults = response?.mapItems ?? []
            }
        }
    }

    private func selectSearchResult(_ item: MKMapItem) {
        viewModel.destination = item.placemark.coordinate
        // マップをその場所に移動
        cameraPosition = .region(MKCoordinateRegion(
            center: item.placemark.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
        searchText = item.name ?? ""
        searchResults = []
    }

    // MARK: - ヘルパービュー

    private func infoCell(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.subheadline)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.caption2).opacity(0.7)
                Text(value).font(.subheadline.bold())
            }
        }
        .foregroundColor(paceTextColor)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func speedCell(label: String, value: String, unit: String, icon: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon).font(.caption).opacity(0.7)
            Text(label).font(.caption2).opacity(0.7)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value).font(.title3.bold())
                Text(unit).font(.caption2).opacity(0.8)
            }
        }
        .foregroundColor(paceTextColor)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - ユーティリティ

    private func formattedDistance(_ meters: Double) -> String {
        meters >= 1000
            ? String(format: "%.1f km", meters / 1000)
            : String(format: "%.0f m", meters)
    }

    private var paceBackgroundColor: Color {
        guard viewModel.isNavigating else { return Color(.systemGray6) }
        switch viewModel.paceStatus {
        case .onPace:         return Color.blue.opacity(0.85)
        case .slightlyBehind: return Color.yellow.opacity(0.85)
        case .behind, .overdue: return Color.red.opacity(0.85)
        }
    }

    private var paceTextColor: Color {
        switch viewModel.paceStatus {
        case .onPace, .behind, .overdue: return .white
        case .slightlyBehind:            return Color(.darkText)
        }
    }
}

#Preview {
    ContentView()
}
