internal import CoreData
import Combine

@objc(WorkoutSession)
final class WorkoutSession: NSManagedObject, Identifiable {
    @NSManaged var id: UUID?
    @NSManaged var date: Date?
    @NSManaged var durationSeconds: Int32
    @NSManaged var trackName: String?
    @NSManaged var genre: String?
}

extension WorkoutSession {
    /// FetchRequest sorted newest-first, used by SessionsView.
    static var newestFirstRequest: NSFetchRequest<WorkoutSession> {
        let req = NSFetchRequest<WorkoutSession>(entityName: "WorkoutSession")
        req.sortDescriptors = [NSSortDescriptor(keyPath: \WorkoutSession.date, ascending: false)]
        return req
    }
}
