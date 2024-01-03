import java.io.File
import java.time.Duration
import java.time.LocalDateTime
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import kotlin.system.exitProcess

// 保留3小时内所有
// 3小时-7天 一小时一个
// 删除超过7天的
val backupDir = File("/hdd/user_backup/gtnh/backups")
val backups: Array<File> = backupDir.listFiles() ?: exitProcess(0)
val formatter: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd-HH-mm-ss")
val printFormatter: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyy.MM.dd HH:mm:ss")

while (true) {
    val now: LocalDateTime = LocalDateTime.now()
    println("开始检查: ${now.format(printFormatter)}")
    val preHour = mutableMapOf<String, String>()
    backups.filter {
        it.isDirectory
    }.map {
        it to LocalDateTime.parse(it.name, formatter)
    }.sortedBy {
        it.second.toEpochSecond(ZoneOffset.of("+8"))
    }.forEach { (file, dateTime) ->
        val hoursDiff = Duration.between(dateTime, now).toHours()
        // 保留最近 3 小时内的备份
        if (hoursDiff <= 3) return@forEach

        // 保留 3小时-7天 每小时的第一个备份
        if (hoursDiff <= 168) {
            val hourKey = "${dateTime.year}-${dateTime.monthValue}-${dateTime.dayOfMonth}-${dateTime.hour}"
            // 保留每小时的第一份
            val exists = preHour[hourKey]
            if (exists == null) {
                preHour[hourKey] = dateTime.format(printFormatter)
                return@forEach
            }
            file.deleteRecursively()
            println("删除${dateTime.format(printFormatter)}: 已有当前小时的备份${exists}")
            return@forEach
        }

        // 删除7天以前的备份
        file.deleteRecursively()
        println("删除${dateTime.format(printFormatter)}: 7天前")
    }

    Thread.sleep(10 * 60 * 1000)
}