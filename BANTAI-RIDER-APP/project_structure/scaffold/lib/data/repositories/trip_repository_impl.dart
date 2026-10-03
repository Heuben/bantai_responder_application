import '../../domain/entities/trip_entity.dart';
import '../../domain/repositories/trip_repository.dart';

class TripRepositoryImpl implements TripRepository {
  @override
  Future<List<TripEntity>> getTrips() async {
    return const [];
  }
}
