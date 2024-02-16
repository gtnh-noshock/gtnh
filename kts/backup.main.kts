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

// 保留3小时内所有
// 3小时-7天 一小时一个
// 删除超过7天的
val backupDir = File("/hdd/user_backup/gtnh/backups")
val formatter: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd-HH-mm-ss")
val printFormatter: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyy.MM.dd HH:mm:ss")
println("开始存档备份")

fun File.size() = String.format("%.2f", this.length() / 1024.0 / 1024.0 / 1024.0)

runBlocking(Dispatchers.IO) {
    while (true) {
        launch {
            Runtime.getRuntime().exec("tmux send-keys -t gtnh:0 save-all C-m").waitFor()
            Thread.sleep(1000)
            val dirName = formatter.format(LocalDateTime.now())
            File(dirName).mkdir()
            val fileName = "$dirName/backup.zip"
            println("开始备份: $fileName")
            launch {
                Runtime.getRuntime()
                    .exec(arrayOf("tmux", "send-keys", "-t", "gtnh:0", "say 开始备份: $fileName", "C-m"))
                    .waitFor()
            }
            launch {
                val t = System.currentTimeMillis()
                val exec = Runtime.getRuntime().exec("zip -qr $fileName /home/gtnh/gtnh-2.5.0/World")
                if (exec.waitFor() != 0) {
                    println("[WARN] ${exec.inputStream.bufferedReader().use { it.readText() }}")
                    println("备份时出现异常: $fileName")
                    Runtime.getRuntime()
                        .exec(arrayOf("tmux", "send-keys", "-t", "gtnh:0", "say 备份时出现异常: $fileName", "C-m"))
                        .waitFor()
                } else {
                    val now = System.currentTimeMillis()
                    println("完成备份: $fileName 耗时${now - t}ms")
                    Runtime.getRuntime()
                        .exec(arrayOf("tmux", "send-keys", "-t", "gtnh:0", "say 完成备份: $fileName 耗时${now - t}ms 备份${File(fileName).size()}", "C-m"))
                        .waitFor()
                }
            }
        }
        launch {
            val now: LocalDateTime = LocalDateTime.now()
            println("开始检查过期备份")
            val preHour = mutableMapOf<String, String>()
            var delete = 0
            backupDir.listFiles()!!.filter {
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
            if (delete != 0) launch {
                Runtime.getRuntime()
                    .exec(arrayOf("tmux", "send-keys", "-t", "gtnh:0", "say 共删除过期备份 $delete 个", "C-m"))
                    .waitFor()
            }
            println("完成检查过期备份 共删除$delete")
        }
        delay(5 * 60 * 1000)
        println()
    }
}