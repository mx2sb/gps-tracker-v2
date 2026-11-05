# Miles GPS · prueba privada gratuita para iPhone

## Entrega actual: 0.1.2

Para actualizar la instalación existente, sigue **ACTUALIZAR.md**. Esta revisión enlaza explícitamente los botones de grabación de la web con la pestaña nativa, verifica la cuenta al iniciar, continúa tras conceder el permiso de ubicación y muestra un acceso a Ajustes cuando hace falta. Requiere compilarse y probarse en Mac/iPhone; no se ha validado esa compilación desde Windows.

## Corrección 0.1.1 — 4 de noviembre de 2026

El usuario compiló e instaló la versión anterior. Esta revisión aún requiere compilarse y probarse en su Mac/iPhone; no se dispone de Xcode en el equipo Windows de desarrollo.

- El enlace «Grabar recorrido» de la pantalla principal abre ahora la pestaña nativa Grabar GPS, en lugar de apuntar a una sección web oculta.
- La pestaña verifica la sesión automáticamente. Iniciar puede verificarla nuevamente y muestra el resultado; se mantiene el botón de verificación manual.
- Al conceder ubicación en el primer inicio, la grabación continúa sin exigir una segunda pulsación.
- Finalizar permite un punto: se conserva sin inventar distancia. Un intento vacío queda cerrado sólo localmente y permite volver a iniciar.

Actualización: abre este proyecto en Xcode y usa el mismo Team y Bundle Identifier de la instalación anterior. Instala con Run encima de la app existente; no la desinstales. Antes de actualizar, finaliza o pausa cualquier grabación y exporta los puntos pendientes si los tienes.

Prueba específica: inicia sesión en Web, pulsa «Grabar recorrido» en la pantalla principal y confirma que abre Grabar GPS. Comprueba tu email, pulsa Iniciar, concede ubicación precisa y espera el contador de puntos. Verifica finalizar con cero/un punto y después un recorrido real con la pantalla bloqueada. La revisión web/API acepta un punto desde v9.

Proyecto inicial iOS 16 o posterior. No se ha compilado ni ejecutado en iOS desde este equipo Windows. No incluye una IPA firmada, certificados, Apple ID ni credenciales. La validación con pantalla bloqueada está pendiente. No se ha modificado ni desplegado el servidor actual.

La prueba usa SwiftUI + WKWebView y Core Location directamente, sin dependencias de terceros ni Capacitor. Es una decisión para reducir pasos en esta primera prueba: pestaña Web para la interfaz existente; pestaña Grabar GPS para el grabador nativo. El grabador web se oculta solamente dentro de esta app para evitar dos grabaciones simultáneas. Safari conserva su comportamiento actual.

## Instalación gratuita en tu Mac

1. Copia esta carpeta completa al Mac y abre `Miles.xcodeproj` con una versión de Xcode compatible con tu iPhone. Instala Xcode desde Apple si hace falta.
2. Xcode → Settings → Accounts → añade tu Apple Account. No hace falta comprar la membresía. No envíes tu contraseña ni códigos a este chat.
3. En el proyecto selecciona el target **Miles** → Signing & Capabilities. Mantén **Automatically manage signing** y elige tu **Personal Team**. Cambia Bundle Identifier por uno único, por ejemplo `com.tunombre.milesgps.prueba` si Xcode indica que está ocupado. Background Modes → Location updates ya está configurado; no añadas servicios de pago.
4. Conecta el iPhone por cable, desbloquéalo, acepta Confiar y selecciona el iPhone como destino de ejecución. Activa Modo desarrollador cuando Xcode lo solicite. Si aparece un aviso de confianza del desarrollador, sigue Ajustes → General → VPN y gestión de dispositivos.
5. Pulsa ▶ Run. Xcode compila, firma e instala. No uses Archive/Ad Hoc/TestFlight: esas rutas requieren membresía de pago. La autorización gratuita vence a los siete días; se renueva ejecutando otra vez desde Xcode. Mantén el mismo identificador y no borres la app para conservar archivos. Sincroniza o exporta antes de reinstalar, y no renueves durante una grabación.
6. Instala/conecta Tailscale en el iPhone, con acceso a tu red privada. En la app abre Web e inicia sesión con email/código o admin. En Grabar GPS pulsa **Verificar sesión de la web** y comprueba que sea tu cuenta.
7. Selecciona Caminar/Correr/Bicicleta y pulsa Iniciar. En el primer uso autoriza ubicación **Al usar la app** y **Ubicación precisa**, luego vuelve a pulsar Iniciar. Core Location mantiene la actividad iniciada en primer plano con el indicador de ubicación visible al bloquear la pantalla. No se solicita rastreo permanente fuera de una actividad.

Fuentes: [Personal Team y siete días](https://developer.apple.com/help/account/basics/about-your-developer-account), [Modo desarrollador](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device), [ubicación durante actividad en segundo plano](https://developer.apple.com/documentation/corelocation/cllocationmanager/allowsbackgroundlocationupdates).

## Validación en el Mac y en el teléfono

Antes de instalar, en Terminal dentro de esta carpeta: `bash Comprobar-Mac.command`. Ejecuta las pruebas Swift del archivo local y segmentación y compila para simulador sin firma. Estos checks todavía no se han ejecutado aquí por falta de macOS/Xcode. Una compilación del simulador no prueba el GPS físico ni la firma Personal Team.

Prueba con una actividad corta y real, sin tocar actividades anteriores:

- Inicia al aire libre y espera a ver varios puntos y buena precisión.
- Bloquea la pantalla durante 3–5 minutos caminando. Desbloquea y comprueba que el número de puntos creció durante ese intervalo. La prueba no se considera aprobada si solo crece después de desbloquear.
- Pausa, desplázate y reanuda. El segmento cambia para no unir el tramo de pausa.
- Desactiva internet durante otro tramo. Los puntos deben seguir acumulándose. Recupera conexión y Tailscale y pulsa Sincronizar.
- Finaliza, sincroniza y abre la web. Selecciona el recorrido recién creado; revisa trayectoria, hora y millas. Actualiza la página Web si sigue mostrando el estado anterior.
- Repite Sincronizar: debe conservarse un solo UUID/recorrido. Comprueba separación entre cuentas.
- En otra prueba, interrumpe la app con puntos pendientes. Al abrir recupera el archivo en pausa y exige reanudar; no promete grabación tras cierre forzado, apagado o terminación por iOS.
- Si falla, conserva/exporta la copia local y anota qué paso falló. No borres la app para resolverlo.

## Almacenamiento y sincronización

Cada posición se escribe de forma atómica en Application Support con protección de archivo que permite seguir escribiendo tras el primer desbloqueo del dispositivo. Se conservan coordenadas, hora UTC, precisión, velocidad/altitud disponibles y segmentos. No se generan puntos ficticios. Datos de precisión pobre se conservan en bruto; el servidor aplica sus filtros de distancia habituales.

Reutiliza sesión HttpOnly de la web mediante WKHTTPCookieStore. Nunca extrae contraseñas ni usa el token de mantenimiento. Antes de enviar consulta `/api/auth/me` y solo sincroniza archivos de esa cuenta. Los requests están limitados al servidor HTTPS fijo y no siguen redirecciones a otro origen. El backend existente sigue autorizando propiedad e idempotencia.

En primer plano reintenta cada 15 segundos; envía bloques a `/api/live/{id}` y al finalizar usa `/api/activities`. En segundo plano el guardado nativo sigue activo, pero los timers/red pueden suspenderse: el mapa remoto no tiene garantía de actualización cada 15 segundos. Al volver a primer plano reintenta sin borrar originales ni cambiar UUID. Una sesión vencida o servidor inaccesible no elimina los puntos. No se ha añadido upload mediante URLSession de segundo plano en esta prueba.

Límites: máximo 200.000 puntos por actividad; esta versión reescribe el archivo JSON completo, adecuada para recorridos cortos de validación. Antes de recorridos largos se debe medir consumo/latencia y migrar a un diario o SQLite si hace falta. No hay precisión deportiva garantizada hasta comparar un recorrido real. No borra archivos locales automáticamente. Las copias exportadas incluyen ubicación privada.

## Sin Mac propio

Se puede usar uno prestado para la instalación y las renovaciones. Un Mac remoto permite compilar, pero no resuelve por sí solo el emparejamiento e instalación gratuita del iPhone: habría que preparar un flujo adicional. AltStore/AltServer en Windows es otra vía de instalación/renovación de una IPA compatible, no un compilador de iOS y no elimina la caducidad gratuita. Para esta prueba usamos el Mac al que ya tienes acceso.
