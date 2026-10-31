package id.jedasholat.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.compose.*
import id.jedasholat.ui.*
import id.jedasholat.ui.screens.*

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            val vm: JedaViewModel = viewModel()
            val state by vm.state.collectAsStateWithLifecycle()
            val lifecycle = LocalLifecycleOwner.current.lifecycle
            DisposableEffect(lifecycle) {
                val observer = LifecycleEventObserver { _, event -> if (event == Lifecycle.Event.ON_RESUME) vm.refresh() }
                lifecycle.addObserver(observer)
                onDispose { lifecycle.removeObserver(observer) }
            }
            JedaTheme(state.settings.theme) {
                if (state.loading) { Box(Modifier.fillMaxSize()) { CircularProgressIndicator() } }
                else if (!state.settings.onboardingCompleted) OnboardingScreen(state, vm)
                else {
                    val nav = rememberNavController()
                    val backstack by nav.currentBackStackEntryAsState()
                    val route = backstack?.destination?.route ?: "home"
                    Scaffold(bottomBar = { NavigationBar {
                        listOf(Triple("home", "Beranda", "⌂"), Triple("schedule", "Jadwal", "◷"), Triple("apps", "Aplikasi", "▦"), Triple("settings", "Pengaturan", "⚙")).forEach { (r, label, icon) ->
                            NavigationBarItem(selected = route == r, onClick = { nav.navigate(r) { launchSingleTop = true; popUpTo("home") } },
                                icon = { Text(icon) }, label = { Text(label) })
                        }
                    } }, snackbarHost = { state.message?.let { Snackbar(modifier = Modifier.padding(), action = { TextButton(onClick = { vm.message(null) }) { Text("Tutup") } }) { Text(it) } } }) { padding ->
                        Box(Modifier.padding(padding).fillMaxSize()) {
                            NavHost(nav, startDestination = "home", modifier = Modifier.fillMaxSize()) {
                                composable("home") { HomeScreen(state, vm) { nav.navigate(it) { launchSingleTop = true } } }
                                composable("schedule") { ScheduleScreen(state, vm) }
                                composable("apps") { AppsScreen(state, vm) }
                                composable("settings") { SettingsScreen(state, vm) }
                            }
                        }
                    }
                }
            }
        }
    }
    override fun onResume() { super.onResume() }
}
