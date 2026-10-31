package id.jedasholat.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.compose.*
import id.jedasholat.ui.*
import id.jedasholat.ui.screens.*
import kotlinx.coroutines.launch

private data class Destination(val route: String, val label: String, val icon: JedaGlyph)
private val destinations = listOf(
    Destination("home", "Beranda", JedaGlyph.HOME),
    Destination("schedule", "Jadwal", JedaGlyph.CALENDAR),
    Destination("apps", "Aplikasi", JedaGlyph.GRID),
    Destination("settings", "Pengaturan", JedaGlyph.SETTINGS),
)

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
                Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
                    when {
                        state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(18.dp)) {
                                JedaMark(72.dp, crescent = MaterialTheme.colorScheme.primary)
                                Text("JedaSholat", style = MaterialTheme.typography.titleLarge)
                                CircularProgressIndicator(Modifier.size(24.dp), strokeWidth = 2.dp)
                            }
                        }
                        !state.settings.onboardingCompleted -> OnboardingScreen(state, vm)
                        else -> MainNavigation(state, vm)
                    }
                }
            }
        }
    }
}

@Composable private fun MainNavigation(state: UiState, vm: JedaViewModel) {
    val nav = rememberNavController()
    val backstack by nav.currentBackStackEntryAsState()
    val route = backstack?.destination?.route ?: "home"
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    LaunchedEffect(state.message) {
        val message = state.message ?: return@LaunchedEffect
        snackbar.showSnackbar(message, withDismissAction = true)
        vm.message(null)
    }
    fun go(target: String) = nav.navigate(target) {
        launchSingleTop = true; restoreState = true
        popUpTo("home") { saveState = true }
    }
    Scaffold(
        contentWindowInsets = WindowInsets.safeDrawing,
        snackbarHost = { SnackbarHost(snackbar) },
        bottomBar = {
            NavigationBar(containerColor = MaterialTheme.colorScheme.surface, tonalElevation = 0.dp, modifier = Modifier.heightIn(min = 80.dp)) {
                destinations.forEach { item ->
                    NavigationBarItem(selected = route == item.route, onClick = { go(item.route) },
                        icon = { JedaIcon(item.icon, modifier = Modifier.size(23.dp)) },
                        label = { Text(item.label, style = MaterialTheme.typography.labelMedium, maxLines = 1) },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = MaterialTheme.colorScheme.onPrimaryContainer,
                            selectedTextColor = MaterialTheme.colorScheme.primary,
                            indicatorColor = MaterialTheme.colorScheme.primaryContainer,
                            unselectedIconColor = MaterialTheme.colorScheme.onSurfaceVariant,
                            unselectedTextColor = MaterialTheme.colorScheme.onSurfaceVariant,
                        ))
                }
            }
        },
    ) { padding ->
        NavHost(nav, startDestination = "home", modifier = Modifier.fillMaxSize().padding(padding)) {
            composable("home") { HomeScreen(state, vm, ::go) }
            composable("schedule") { ScheduleScreen(state, vm) }
            composable("apps") { AppsScreen(state, vm) }
            composable("settings") { SettingsScreen(state, vm) }
        }
    }
}
