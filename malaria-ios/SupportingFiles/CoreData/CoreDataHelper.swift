import Foundation

/// Manages `NSManagedObjectContext`
public class CoreDataHelper: NSObject {
    /// Singleton
    public static let sharedInstance = CoreDataHelper()
    
    /// Init
    override init(){
        super.init()
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: "contextDidSaveContext:",
                                       name: NSManagedObjectContextDidSaveNotification, object: nil)
    }
    
    deinit{
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    private lazy var managedObjectContext: NSManagedObjectContext? = {
        let coordinator = CoreDataStore.sharedInstance.persistentStoreCoordinator
        if coordinator == nil {
            return nil
        }
        
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
        }()
    
    /// Creates a new background context with the mainContext as parent
    /// Create background context to keep in sync with the database
    ///
    /// - returns: `NSManagedObjectContext`
    public func createBackgroundContext() -> NSManagedObjectContext?{
        let coordinator = CoreDataStore.sharedInstance.persistentStoreCoordinator
        if coordinator == nil {
            return nil
        }
        
        let backgroundContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        backgroundContext.parentContext = self.managedObjectContext
        return backgroundContext
    }
    
    /// Save the context
    ///
    /// - parameter `NSManagedObjectContext`:: context to be saved
    public func saveContext (context: NSManagedObjectContext) {
        if context.hasChanges {
            do {
                try context.save()
            } catch let error as NSError {
                Logger.Error("Unresolved error \(error), \(error.userInfo)")
            }
        }
    }
    
    
    /// Callback for multi-threading. Syncronizes the background context with the main context. 
    /// Then the parent context, that has direct connection with persistent storage saves
    internal func contextDidSaveContext(notification: NSNotification) {
        let sender = notification.object as! NSManagedObjectContext
        if sender != self.managedObjectContext {
            self.managedObjectContext!.performBlock {
                self.managedObjectContext!.mergeChangesFromContextDidSaveNotification(notification)
                self.saveContext(self.managedObjectContext!)
            }
        }
    }
}
