import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_model.dart';
import '../../services/doctor_service.dart';
import '../../constants/doctor_constants.dart';

final doctorServiceProvider = Provider<DoctorService>((ref) {
  return DoctorService();
});

final doctorSearchProvider = StateNotifierProvider<DoctorSearchNotifier, AsyncValue<List<UserModel>>>((ref) {
  return DoctorSearchNotifier(ref);
});

class DoctorSearchNotifier extends StateNotifier<AsyncValue<List<UserModel>>> {
  final DoctorService _doctorService;

  DoctorSearchNotifier(Ref ref)
      : _doctorService = ref.read(doctorServiceProvider),
        super(const AsyncValue.loading()) {
    _loadAllDoctors();
  }

  Future<void> _loadAllDoctors() async {
    try {
      state = const AsyncValue.loading();
      final doctors = await _doctorService.getAllDoctors();
      state = AsyncValue.data(doctors);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> searchByName(String query) async {
    if (query.trim().isEmpty) {
      _loadAllDoctors();
      return;
    }

    try {
      state = const AsyncValue.loading();
      final doctors = await _doctorService.searchDoctorsByName(query);
      state = AsyncValue.data(doctors);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow; // Re-throw to allow error handling in UI
    }
  }

  Future<void> searchBySpecialization(String specialization) async {
    if (specialization == 'All') {
      _loadAllDoctors();
      return;
    }

    try {
      state = const AsyncValue.loading();
      final doctors = await _doctorService.searchDoctorsBySpecialization(specialization);
      state = AsyncValue.data(doctors);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow; // Re-throw to allow error handling in UI
    }
  }

  void refresh() {
    _loadAllDoctors();
  }
}

class DoctorSearchScreen extends ConsumerStatefulWidget {
  const DoctorSearchScreen({super.key});

  @override
  ConsumerState<DoctorSearchScreen> createState() => _DoctorSearchScreenState();
}

class _DoctorSearchScreenState extends ConsumerState<DoctorSearchScreen> {
  final _searchController = TextEditingController();
  String _selectedSpecialization = 'All';

  @override
  void initState() {
    super.initState();
    // Check for specialization query parameter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = GoRouterState.of(context).uri;
      final specialization = uri.queryParameters['specialization'];
      if (specialization != null && specialization.isNotEmpty) {
        setState(() => _selectedSpecialization = specialization);
        ref.read(doctorSearchProvider.notifier).searchBySpecialization(specialization);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(doctorSearchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a Doctor'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search by name',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onChanged: (value) {
                    ref.read(doctorSearchProvider.notifier).searchByName(value);
                  },
                ),
                const SizedBox(height: 12),
                // Specialization filter
                DropdownButtonFormField<String>(
                  initialValue: _selectedSpecialization,
                  decoration: InputDecoration(
                    labelText: 'Specialization',
                    prefixIcon: const Icon(Icons.medical_services),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  items: [
                    const DropdownMenuItem(value: 'All', child: Text('All Specializations')),
                    ...DoctorConstants.specializations.map(
                      (spec) => DropdownMenuItem(value: spec, child: Text(spec)),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedSpecialization = value);
                      if (value == 'All') {
                        ref.read(doctorSearchProvider.notifier).refresh();
                      } else {
                        ref.read(doctorSearchProvider.notifier).searchBySpecialization(value);
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          // Doctor list
          Expanded(
            child: searchState.when(
              data: (doctors) {
                if (doctors.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No doctors found',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.read(doctorSearchProvider.notifier).refresh();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: doctors.length,
                    itemBuilder: (context, index) {
                      final doctor = doctors[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: InkWell(
                          onTap: () {
                            context.push('/doctor-details/${doctor.uid}');
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundColor: const Color(0xFF2196F3),
                                      child: Text(
                                        doctor.displayName?.substring(0, 1).toUpperCase() ?? 'D',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            doctor.displayName ?? 'Doctor',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (doctor.specialization != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              doctor.specialization!,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                          if (doctor.clinicName != null) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(Icons.local_hospital,
                                                    size: 14, color: Colors.grey.shade600),
                                                const SizedBox(width: 4),
                                                Text(
                                                  doctor.clinicName!,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (doctor.consultationFee != null)
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '\$${doctor.consultationFee!.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2196F3),
                                            ),
                                          ),
                                          const Text(
                                            'per visit',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    if (doctor.isVerified == true)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.verified,
                                                size: 14, color: Colors.green.shade700),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Verified',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.green.shade700,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    const Spacer(),
                                    TextButton.icon(
                                      onPressed: () {
                                        context.push('/doctor-details/${doctor.uid}');
                                      },
                                      icon: const Icon(Icons.arrow_forward, size: 18),
                                      label: const Text('View Profile'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading doctors: ${error.toString()}',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.read(doctorSearchProvider.notifier).refresh();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

