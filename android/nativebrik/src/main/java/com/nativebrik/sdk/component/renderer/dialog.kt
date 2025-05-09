import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.view.View
import android.view.Window
import android.view.WindowManager
import android.widget.FrameLayout
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.window.DialogWindowProvider

@Composable
fun getActivityWindow(): Window? = LocalView.current.context.getActivityWindow()

private tailrec fun Context.getActivityWindow(): Window? =
    when (this) {
        is Activity -> window
        is ContextWrapper -> baseContext.getActivityWindow()
        else -> null
    }

@Composable
fun SetDialogDestinationToEdgeToEdge() {
    val activityWindow = getActivityWindow()
    val dialogWindow = (LocalView.current.parent as? DialogWindowProvider)?.window
    val parentView = LocalView.current.parent as View
    SideEffect {
        if (activityWindow == null || dialogWindow == null) {
            return@SideEffect
        }

        val attributes = WindowManager.LayoutParams()
        attributes.copyFrom(activityWindow.attributes)
        attributes.type = dialogWindow.attributes.type
        dialogWindow.attributes = attributes
        parentView.layoutParams = FrameLayout.LayoutParams(
            activityWindow.decorView.width,
            activityWindow.decorView.height
        )
    }
}
