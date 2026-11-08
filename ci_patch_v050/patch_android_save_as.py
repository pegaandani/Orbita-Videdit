from pathlib import Path
import sys
root=Path(sys.argv[1] if len(sys.argv)>1 else "videdit_project")
files=list((root/"android").rglob("MainActivity.kt"))
if len(files)!=1: raise SystemExit("Cannot identify unique Android activity")
file=files[0]
s=file.read_text(encoding="utf-8")

def replace(before, after):
    global s
    if s.count(before)!=1: raise SystemExit("Native export marker missing: "+before[:90])
    s=s.replace(before,after,1)

replace("import android.content.ContentValues", """import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.content.ContentValues""")
replace('    private val channelName = "orbita_videdit/media_store"', '''    private val channelName = "orbita_videdit/media_store"
    private val saveRequest = 7143
    private var pendingSave: MethodChannel.Result? = null
    private var pendingSource: File? = null
''')
replace('''            if (call.method != "publishVideo") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                val sourcePath = call.argument<String>("sourcePath") ?: error("sourcePath requerido")
                val displayName = call.argument<String>("displayName") ?: File(sourcePath).name
                val uri = publishVideo(File(sourcePath), displayName)
                result.success(uri)
            } catch (e: Exception) {
                result.error("publish_failed", e.message, null)
            }''','''            try {
                val sourcePath = call.argument<String>("sourcePath") ?: error("sourcePath requerido")
                val displayName = call.argument<String>("displayName") ?: File(sourcePath).name
                val source = File(sourcePath)
                if (!source.exists() || source.length() < 1024L) {
                    error("El archivo MP4 no existe o está vacío.")
                }
                when (call.method) {
                    "publishVideo" -> {
                        // Copy off the UI thread. Video exports can be very large.
                        Thread {
                            try {
                                val uri = publishVideo(source, displayName)
                                runOnUiThread { result.success(uri) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("publish_failed", e.message, null) }
                            }
                        }.start()
                    }
                    "saveVideoAs" -> {
                        if (pendingSave != null) {
                            result.error("busy", "Ya hay una selección de destino en curso.", null)
                        } else {
                            pendingSave = result
                            pendingSource = source
                            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "video/mp4"
                                putExtra(Intent.EXTRA_TITLE, displayName)
                            }
                            try {
                                startActivityForResult(intent, saveRequest)
                            } catch (e: Exception) {
                                pendingSave = null
                                pendingSource = null
                                result.error("picker_failed", e.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("export_failed", e.message, null)
            }''')
marker='    private fun publishVideo(source: File, displayName: String): String {'
extra='''    @Deprecated("Uses ACTION_CREATE_DOCUMENT for native destination selection")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != saveRequest) return
        val pending = pendingSave ?: return
        val source = pendingSource
        pendingSave = null
        pendingSource = null
        val uri: Uri? = if (resultCode == Activity.RESULT_OK) data?.data else null
        if (uri == null) {
            pending.success(null)
            return
        }
        if (source == null || !source.exists()) {
            pending.error("source_missing", "El MP4 renderizado ya no existe.", null)
            return
        }
        Thread {
            try {
                contentResolver.openOutputStream(uri, "w")?.use { output ->
                    FileInputStream(source).use { input -> input.copyTo(output, 1024 * 1024) }
                } ?: error("No se pudo abrir la ubicación seleccionada")
                runOnUiThread { pending.success(uri.toString()) }
            } catch (e: Exception) {
                runOnUiThread { pending.error("save_failed", e.message, null) }
            }
        }.start()
    }

'''
replace(marker,extra+marker)
file.write_text(s,encoding="utf-8")
print("Android ACTION_CREATE_DOCUMENT save destination streaming installed; original name/icon preserved.")
