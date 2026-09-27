import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'core/device/device_posture_cubit.dart';
import 'core/device/foldable_device_adapter.dart';
import 'core/network/auth_token_store.dart';
import 'core/network/backend_api_client.dart';
import 'core/storage/app_settings.dart';
import 'features/ai_notes/data/models/note_model.dart';
import 'features/ai_notes/data/repos/notes_repository_impl.dart';
import 'features/ai_notes/data/sources/backend_proxy_data_source.dart';
import 'features/ai_notes/data/sources/notes_local_data_source.dart';
import 'features/ai_notes/domain/repos/notes_repository.dart';
import 'features/ai_notes/domain/usecases/delete_note_usecase.dart';
import 'features/ai_notes/domain/usecases/generate_synthesis_usecase.dart';
import 'features/ai_notes/domain/usecases/get_cached_notes_usecase.dart';
import 'features/ai_notes/domain/usecases/restore_note_usecase.dart';
import 'features/ai_notes/presentation/bloc/ai_notes_bloc.dart';
import 'features/reader/data/models/document_model.dart';
import 'features/reader/data/repos/document_repository_impl.dart';
import 'features/reader/data/sources/document_local_data_source.dart';
import 'features/reader/data/sources/document_picker.dart';
import 'features/reader/domain/repos/document_repository.dart';
import 'features/reader/presentation/bloc/reader_bloc.dart';
import 'features/workspace/presentation/bloc/active_workspace_bloc.dart';

/// Service locator (Factory Method / DI, PRD Section 3).
final sl = GetIt.instance;

const sampleDocumentAsset = 'assets/sample/splitmind_welcome.pdf';

/// Registers every dependency. Parameters exist so tests can substitute fakes.
Future<void> initDependencies({
  required Box<NoteModel> notesBox,
  required Box<DocumentModel> documentsBox,
  required Box<dynamic> settingsBox,
  FoldableDeviceAdapter? deviceAdapter,
  http.Client? httpClient,
  AuthTokenStore? tokenStore,
  DocumentPicker? documentPicker,
  Future<Uint8List> Function()? loadSampleBytes,
}) async {
  await sl.reset();

  // --- Core ---
  sl
    ..registerLazySingleton<AppSettings>(() => AppSettings(settingsBox))
    ..registerLazySingleton<FoldableDeviceAdapter>(
      () => deviceAdapter ?? PlatformFoldableDeviceAdapter(),
      dispose: (adapter) => adapter.dispose(),
    )
    ..registerLazySingleton<DevicePostureCubit>(() => DevicePostureCubit(sl()))
    ..registerLazySingleton<http.Client>(() => httpClient ?? http.Client())
    ..registerLazySingleton<AuthTokenStore>(() => tokenStore ?? SecureAuthTokenStore())
    ..registerLazySingleton<BackendApiClient>(() => BackendApiClient(httpClient: sl(), tokenStore: sl()));

  // --- Mediator: one instance shared by the whole app ---
  sl.registerLazySingleton<ActiveWorkspaceBloc>(ActiveWorkspaceBloc.new);

  // --- AI notes (right pane) ---
  // The backend proxy holds the AI provider key; the app holds none (NFR-2).
  sl
    ..registerLazySingleton<BackendProxyDataSource>(() => BackendProxyDataSource(sl()))
    ..registerLazySingleton<NotesLocalDataSource>(() => NotesLocalDataSourceImpl(notesBox))
    ..registerLazySingleton<NotesRepository>(() => NotesRepositoryImpl(sl(), sl()))
    ..registerLazySingleton(() => GenerateSynthesisUseCase(sl()))
    ..registerLazySingleton(() => GetCachedNotesUseCase(sl()))
    ..registerLazySingleton(() => DeleteNoteUseCase(sl()))
    ..registerLazySingleton(() => RestoreNoteUseCase(sl()))
    ..registerFactory(
      () => AiNotesBloc(
        activeWorkspaceBloc: sl(),
        generateSynthesisUseCase: sl(),
        getCachedNotesUseCase: sl(),
        deleteNoteUseCase: sl(),
        restoreNoteUseCase: sl(),
      ),
    );

  // --- Reader (left pane) ---
  sl
    ..registerLazySingleton<DocumentPicker>(() => documentPicker ?? const FilePickerDocumentPicker())
    ..registerLazySingleton(
      () => DocumentLocalDataSource(box: documentsBox, settings: sl(), storageRoot: getApplicationSupportDirectory),
    )
    ..registerLazySingleton<DocumentRepository>(
      () => DocumentRepositoryImpl(
        local: sl(),
        picker: sl(),
        loadSampleBytes:
            loadSampleBytes ?? () async => (await rootBundle.load(sampleDocumentAsset)).buffer.asUint8List(),
      ),
    )
    ..registerFactory(() => ReaderBloc(activeWorkspaceBloc: sl(), documentRepository: sl()));
}
