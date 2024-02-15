@file:DependsOn("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
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

runBlocking(Dispatchers.IO) {
    while (true) {
        launch {
            println("服务器存档备份")
            Runtime.getRuntime().exec("tmux send-keys -t gtnh:0 save-all C-m").waitFor()
            Thread.sleep(3000)
            val dirName = formatter.format(LocalDateTime.now())
            File(dirName).mkdir()
            val fileName = "$dirName/backup.zip"
            println("开始备份: $fileName")
            launch {
                Runtime.getRuntime().exec(arrayOf("tmux", "send-keys", "-t", "gtnh:0", "say 开始备份: $fileName", "C-m")).waitFor()
            }
            launch {
                Runtime.getRuntime().exec("zip -qr $fileName ../World").waitFor()
                println("完成备份: $fileName")
                Runtime.getRuntime().exec(arrayOf("tmux", "send-keys", "-t", "gtnh:0", "say 完成备份: $fileName", "C-m")).waitFor()
            }

            val now: LocalDateTime = LocalDateTime.now()
            println("开始检查过期备份")
            val preHour = mutableMapOf<String, String>()
            var delete = 0
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
                    delete++
                    println("删除${dateTime.format(printFormatter)}: 已有当前小时的备份${exists}")
                    return@forEach
                }

                // 删除7天以前的备份
                file.deleteRecursively()
                delete++
                println("删除${dateTime.format(printFormatter)}: 7天前")
            }
            launch {
                Runtime.getRuntime().exec(arrayOf("tmux", "send-keys", "-t", "gtnh:0", "say 完成检查过期备份 共删除$delete", "C-m")).waitFor()
            }
            println("完成检查过期备份 共删除$delete")
            println()
        }
        delay(5 * 60 * 1000)
    }
}