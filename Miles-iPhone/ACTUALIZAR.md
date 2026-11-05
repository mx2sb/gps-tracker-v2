# Actualización 0.1.2 del iPhone

Esta entrega es código fuente para Xcode. No contiene una IPA firmada. En Windows se verificaron los archivos, el plist y el ZIP; la compilación Swift y las pruebas físicas de esta revisión siguen pendientes en el Mac/iPhone.

## Conservar tu firma e instalación

1. Pausa/finaliza las grabaciones y exporta los puntos pendientes si los tienes. No desinstales Miles del iPhone.
2. Descomprime el ZIP en el Mac, en una carpeta nueva.
3. Haz una copia de tu proyecto Xcode actual. Sustituye solamente su carpeta `Miles` por la carpeta `Miles` de este ZIP. Contiene los mismos cuatro archivos del proyecto original: Core.swift, Recorder.swift, MilesApp.swift e Info.plist. Conserva tu archivo Miles.xcodeproj: así mantienes Team y Bundle Identifier.
4. Abre tu proyecto habitual, conecta el iPhone y selecciona el mismo destino y Team que antes. Pulsa Run (triángulo). Mantén el mismo Bundle Identifier para actualizar la instalación que conserva tus datos.
5. Como alternativa, abre el proyecto del ZIP y configura exactamente el mismo Team y Bundle Identifier que usaste anteriormente.

## Probar el inicio

1. Conecta Tailscale y abre Miles. En Web inicia sesión con tu cuenta habitual.
2. Pulsa «Grabar recorrido» en la pantalla principal. Debe abrir «Grabar GPS» en la barra inferior. También puedes abrir esa pestaña directamente.
3. Confirma tu email en Cuenta, elige el deporte y pulsa Iniciar recorrido. Aparecerá «Verificando tu sesión…».
4. En la solicitud de ubicación elige «Al usar la app» y activa Ubicación precisa. La grabación debe continuar tras conceder el permiso. Si previamente lo denegaste, usa «Abrir ajustes de ubicación», cambia el permiso y vuelve a pulsar Iniciar.
5. Espera al aire libre hasta ver el contador de puntos aumentar. «GPS iniciado» no significa que ya se hayan recibido posiciones.
6. Camina 1–2 minutos, bloquea la pantalla durante parte del recorrido, vuelve a abrir y comprueba los puntos. Pulsa Finalizar y guardar, y Sincronizar ahora con Tailscale conectado. Comprueba el recorrido en la web.
7. En la sección inferior debe verse «Versión 0.1.2 · GPS nativo». Si no aparece, aún estás usando la versión anterior.

El grabador conserva los puntos sin conexión durante un recorrido iniciado. Para empezar una nueva actividad esta versión verifica la cuenta con el servidor. No fuerces el cierre de la app durante la prueba. Si algo falla, anota el mensaje exacto y conserva la copia local.

## Validación del proyecto completo en Mac

Desde la carpeta del ZIP ejecuta `bash Comprobar-Mac.command`. Ejecuta las pruebas del núcleo Swift y la compilación para simulador sin firma. Esto no sustituye la prueba de GPS y pantalla bloqueada en un iPhone real.
