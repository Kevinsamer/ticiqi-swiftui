//  Script library — grid view of scripts, entry point of the app
//  ticiqi
//

import SwiftUI
import UniformTypeIdentifiers

struct ScriptLibraryView: View {
    let engine: PrompterEngine
    let serverManager: PrompterServerManager
    let store: ScriptStore
    @State private var settings = PrompterSettings.load()
    @State private var showFileImporter = false
    @State private var showSettings = false
    @State private var navigateTo: StoredScript?
    @State private var renameTarget: StoredScript?
    @State private var renameText = ""
    @State private var deleteTarget: StoredScript?
    @State private var showDeleteConfirm = false
    @State private var refreshTrigger = false

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 16)
    ]

    private var currentScripts: [StoredScript] {
        _ = refreshTrigger
        return store.scripts
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        AddScriptCardView()
                            .onTapGesture { showFileImporter = true }

                        ForEach(currentScripts, id: \.id) { script in
                            scriptCard(for: script)
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }

                serverURLBadge
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("稿件库")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFileImporter = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(item: $navigateTo) { script in
                prompterView(for: script)
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheetView(settings: $settings)
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [
                    .plainText, .text,
                    UTType(filenameExtension: "md") ?? .text,
                    UTType(filenameExtension: "docx") ?? .data
                ],
                allowsMultipleSelection: false
            ) { result in handleFileImport(result) }
            .sheet(isPresented: Binding(
                get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } }
            )) {
                RenameSheetView(name: $renameText, onConfirm: confirmRename)
            }
            .confirmationDialog("确认删除", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("删除", role: .destructive) { confirmDelete() }
                Button("取消", role: .cancel) { deleteTarget = nil }
            } message: {
                if let target = deleteTarget {
                    Text("确定要删除「\(target.title)」吗？此操作不可撤销。")
                }
            }
        }
    }

    // MARK: - Server URL badge

    private var serverURLBadge: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if let ip = serverManager.ipURL {
                Text(ip)
                    .font(.caption2)
                    .monospaced()
            }
            Text(PrompterServerManager.bonjourHost + ":\(PrompterServerManager.port)")
                .font(.caption2)
                .monospaced()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(.trailing, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Prompter navigation

    @ViewBuilder
    private func prompterView(for script: StoredScript) -> some View {
        PrompterHostView(
            engine: engine,
            serverManager: serverManager,
            document: store.toDocument(script),
            settings: settings
        )
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Card builder

    @ViewBuilder
    private func scriptCard(for script: StoredScript) -> some View {
        ScriptCardView(
            script: script,
            onRename: {
                renameText = script.title
                renameTarget = script
            },
            onDelete: {
                deleteTarget = script
                showDeleteConfirm = true
            }
        )
        .contentShape(.interaction, RoundedRectangle(cornerRadius: 16))
        .onTapGesture { navigateTo = script }
    }

    // MARK: - Actions

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        Task {
            do {
                _ = try await store.importFromURL(url)
            } catch {
                print("导入失败: \(error.localizedDescription)")
            }
        }
    }

    private func confirmRename() {
        guard let target = renameTarget, !renameText.isEmpty else { return }
        store.updateTitle(id: target.id, newTitle: renameText)
        refreshTrigger.toggle()
        renameTarget = nil
    }

    private func confirmDelete() {
        guard let target = deleteTarget else { return }
        store.delete(id: target.id)
        deleteTarget = nil
    }
}
