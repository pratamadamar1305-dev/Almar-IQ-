package id.jedasholat.data

import androidx.room.*
import id.jedasholat.core.*
import kotlinx.coroutines.flow.Flow

@Entity(tableName = "sessions")
data class SessionEntity(
    @PrimaryKey val id: String, val date: String, val prayer: String, val start: Long, val end: Long,
    val mode: String, val status: String, val snoozedUntil: Long?, val snoozeUsed: Boolean, val reason: String?,
)
fun SessionEntity.toDomain() = Session(id, date, Prayer.valueOf(prayer), start, end, Mode.valueOf(mode), SessionStatus.valueOf(status), snoozedUntil, snoozeUsed, reason)
fun Session.toEntity() = SessionEntity(id, date, prayer.name, start, end, mode.name, status.name, snoozedUntil, snoozeUsed, reason)
@Dao
interface SessionDao {
    @Query("SELECT * FROM sessions ORDER BY start DESC") fun observe(): Flow<List<SessionEntity>>
    @Query("SELECT * FROM sessions") suspend fun all(): List<SessionEntity>
    @Upsert suspend fun put(items: List<SessionEntity>)
    @Query("DELETE FROM sessions WHERE end < :cutoff") suspend fun prune(cutoff: Long)
    @Query("DELETE FROM sessions WHERE status IN ('COMPLETED','CANCELLED','INTERRUPTED','MISSED')") suspend fun clearHistory()
    @Query("DELETE FROM sessions") suspend fun clear()
}
@Database(entities = [SessionEntity::class], version = 1, exportSchema = false)
abstract class JedaDatabase : RoomDatabase() { abstract fun sessions(): SessionDao }
