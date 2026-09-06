import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Sistema de diseño de Atlas.
///
/// Concentra en un solo lugar el color, la tipografía, los radios y el estilo
/// de cada componente. Las pantallas no fijan colores ni tamaños a mano: los
/// piden al tema. Así la aplicación se ve igual en todas partes y un cambio de
/// identidad visual se hace aquí y no en veinte archivos.
///
/// Hay tema claro y tema oscuro, ambos derivados de la misma semilla de marca,
/// y la aplicación sigue la preferencia del sistema.
class TemaAtlas {
  const TemaAtlas._();

  // ------------------------------------------------------------------ marca

  /// Índigo de la marca. De aquí sale toda la paleta.
  static const Color marca = Color(0xFF5B4BE8);

  /// Acento frío, para datos y diagnóstico.
  static const Color acento = Color(0xFF06B6D4);

  /// Acento cálido, para lo que exige atención sin ser un error.
  static const Color realce = Color(0xFFF59E0B);

  static const Color _exito = Color(0xFF10B981);
  static const Color _fondoClaro = Color(0xFFF5F6FB);
  static const Color _fondoOscuro = Color(0xFF0E1016);
  static const Color _superficieOscura = Color(0xFF161A23);

  // ------------------------------------------------------------------ forma

  static const double radioGrande = 20;
  static const double radioMedio = 16;
  static const double radioChico = 12;

  static const BorderRadius bordeGrande =
      BorderRadius.all(Radius.circular(radioGrande));
  static const BorderRadius bordeMedio =
      BorderRadius.all(Radius.circular(radioMedio));

  /// Degradado de la marca, usado en las cabeceras y en el logotipo.
  static const LinearGradient degradado = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5B4BE8), Color(0xFF8B5CF6), Color(0xFF06B6D4)],
    stops: [0.0, 0.55, 1.0],
  );

  /// Versión corta del degradado, para superficies pequeñas (avatar, icono).
  static const LinearGradient degradadoCorto = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6D5BF0), Color(0xFF06B6D4)],
  );

  // ------------------------------------------------------------------ temas

  static ThemeData claro() => _construir(Brightness.light);
  static ThemeData oscuro() => _construir(Brightness.dark);

  static ThemeData _construir(Brightness brillo) {
    final esOscuro = brillo == Brightness.dark;

    final colores = ColorScheme.fromSeed(
      seedColor: marca,
      brightness: brillo,
    ).copyWith(
      secondary: acento,
      tertiary: realce,
      surface: esOscuro ? _superficieOscura : Colors.white,
    );

    final fondo = esOscuro ? _fondoOscuro : _fondoClaro;
    final base = ThemeData(colorScheme: colores, useMaterial3: true);
    final tipografia = _tipografia(base.textTheme, colores);
    final contorno = colores.outlineVariant.withValues(alpha: esOscuro ? 0.5 : 0.7);

    return base.copyWith(
      scaffoldBackgroundColor: fondo,
      textTheme: tipografia,

      appBarTheme: AppBarTheme(
        backgroundColor: fondo,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colores.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: tipografia.titleLarge,
        systemOverlayStyle:
            esOscuro ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),

      // Tarjetas planas con un filete: menos ruido visual que una sombra, y
      // se distinguen igual del fondo en claro y en oscuro.
      cardTheme: CardThemeData(
        color: colores.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: bordeGrande,
          side: BorderSide(color: contorno),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: esOscuro
            ? Colors.white.withValues(alpha: 0.04)
            : colores.surfaceContainerHighest.withValues(alpha: 0.45),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        prefixIconColor: WidgetStateColor.resolveWith(
          (estados) => estados.contains(WidgetState.error)
              ? colores.error
              : estados.contains(WidgetState.focused)
                  ? colores.primary
                  : colores.onSurfaceVariant,
        ),
        border: OutlineInputBorder(
          borderRadius: bordeMedio,
          borderSide: BorderSide(color: contorno),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: bordeMedio,
          borderSide: BorderSide(color: contorno),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: bordeMedio,
          borderSide: BorderSide(color: colores.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: bordeMedio,
          borderSide: BorderSide(color: colores.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: bordeMedio,
          borderSide: BorderSide(color: colores.error, width: 1.8),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: bordeMedio,
          borderSide: BorderSide(color: contorno.withValues(alpha: 0.4)),
        ),
        helperStyle: tipografia.bodySmall,
        errorStyle: tipografia.bodySmall?.copyWith(
          color: colores.error,
          fontWeight: FontWeight.w500,
        ),
        labelStyle: TextStyle(color: colores.onSurfaceVariant),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 54),
          shape: const RoundedRectangleBorder(borderRadius: bordeMedio),
          textStyle: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 54),
          side: BorderSide(color: colores.outline.withValues(alpha: 0.6)),
          shape: const RoundedRectangleBorder(borderRadius: bordeMedio),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radioChico)),
          ),
          textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: colores.surfaceContainerHighest.withValues(alpha: 0.6),
        side: BorderSide(color: contorno),
        labelStyle: tipografia.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(999)),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: colores.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colores.primary.withValues(alpha: 0.14),
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (estados) => TextStyle(
            fontSize: 12,
            fontWeight:
                estados.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: estados.contains(WidgetState.selected)
                ? colores.primary
                : colores.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (estados) => IconThemeData(
            size: 24,
            color: estados.contains(WidgetState.selected)
                ? colores.primary
                : colores.onSurfaceVariant,
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: colores.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: bordeGrande),
        titleTextStyle: tipografia.titleLarge,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: esOscuro ? const Color(0xFF262B36) : const Color(0xFF1F2430),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: const RoundedRectangleBorder(borderRadius: bordeMedio),
        insetPadding: const EdgeInsets.all(16),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colores.primary,
        foregroundColor: colores.onPrimary,
        elevation: 2,
        highlightElevation: 4,
        shape: const RoundedRectangleBorder(borderRadius: bordeMedio),
      ),

      listTileTheme: ListTileThemeData(
        shape: const RoundedRectangleBorder(borderRadius: bordeMedio),
        iconColor: colores.onSurfaceVariant,
      ),

      dividerTheme: DividerThemeData(color: contorno, thickness: 1, space: 1),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (e) => e.contains(WidgetState.selected) ? Colors.white : null,
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colores.primary,
        linearTrackColor: colores.primary.withValues(alpha: 0.15),
      ),

      // Transición entre pantallas más suave que la de Android por defecto.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _tipografia(TextTheme base, ColorScheme colores) {
    return base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.7,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
      bodySmall: base.bodySmall?.copyWith(
        height: 1.4,
        color: colores.onSurfaceVariant,
      ),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  // ------------------------------------------------------- color por estado

  /// Color con el que se pinta el estado de una idea.
  ///
  /// El backend maneja `borrador`, `procesando` y `publicada`; cualquier otro
  /// valor cae en el color neutro en lugar de romper la interfaz.
  static Color colorDeEstado(String estado, ColorScheme colores) =>
      switch (estado.toLowerCase()) {
        'publicada' => _exito,
        'procesando' => realce,
        'borrador' => colores.primary,
        _ => colores.onSurfaceVariant,
      };

  static IconData iconoDeEstado(String estado) =>
      switch (estado.toLowerCase()) {
        'publicada' => Icons.check_circle_outline,
        'procesando' => Icons.autorenew,
        'borrador' => Icons.edit_note_outlined,
        _ => Icons.circle_outlined,
      };
}
