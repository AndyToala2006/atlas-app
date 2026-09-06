import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../estado/ambito_atlas.dart';
import '../modelos/respuesta_api.dart';
import '../tema/tema_atlas.dart';
import '../widgets/bloque_resultado.dart';

/// Diagnóstico de conectividad (Taller Semana 9).
///
/// Es una ruta pública a propósito: `GET /health` no exige token y sirve para
/// distinguir un problema de red de un problema de credenciales antes de
/// intentar iniciar sesión. Por eso se llega a ella desde el propio login.
class PantallaConexion extends StatefulWidget {
  const PantallaConexion({super.key});

  @override
  State<PantallaConexion> createState() => _PantallaConexionState();
}

class _PantallaConexionState extends State<PantallaConexion> {
  bool _cargando = false;
  Widget? _resultado;

  Future<void> _probar() async {
    final api = AmbitoAtlas.de(context).api;
    setState(() {
      _cargando = true;
      _resultado = null;
    });
    try {
      final respuesta = await api.verificarSalud();
      final datos = respuesta.datos;
      if (!mounted) return;
      setState(() {
        _resultado = BloqueResultado(
          titulo: 'Conexión establecida',
          detalle: 'GET /health respondió: '
              'status=${datos['status']}, servicio=${datos['servicio']}',
          respuesta: respuesta,
        );
      });
    } on ErrorApi catch (e) {
      if (!mounted) return;
      setState(() {
        _resultado = BloqueResultado(
          titulo: 'No hay conexión con el backend',
          detalle: e.mensaje,
          sugerencia: e.sugerencia,
          esError: true,
        );
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Diagnóstico de conexión')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Comprueba que el teléfono alcanza el backend antes de iniciar '
            'sesión. Este endpoint es público: no requiere token.',
            style: tema.textTheme.bodySmall,
          ),
          const SizedBox(height: 20),

          Text('Configuración del entorno', style: tema.textTheme.titleMedium),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  _Fila(
                    icono: Icons.link,
                    clave: 'API_BASE_URL',
                    valor: AppConfig.apiBaseUrl,
                  ),
                  _Fila(
                    icono: Icons.tune,
                    clave: 'APP_ENV',
                    valor: AppConfig.entorno,
                  ),
                  _Fila(
                    icono: Icons.timer_outlined,
                    clave: 'Timeout',
                    valor: '${AppConfig.timeout.inSeconds} s',
                    ultima: true,
                  ),
                ],
              ),
            ),
          ),

          if (AppConfig.usaTraficoSinCifrar) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: TemaAtlas.realce.withValues(alpha: 0.09),
                borderRadius: TemaAtlas.bordeMedio,
                border: Border.all(
                  color: TemaAtlas.realce.withValues(alpha: 0.32),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 18, color: TemaAtlas.realce),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tráfico sin cifrar (http) autorizado únicamente para el '
                      'host de desarrollo declarado en network_security_config.xml. '
                      'Esta excepción debe eliminarse antes de cualquier '
                      'distribución de la aplicación.',
                      style: tema.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: _cargando ? null : _probar,
            icon: _cargando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.network_check),
            label: const Text('Probar conexión con la API'),
          ),
          const SizedBox(height: 20),
          ?_resultado,
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.icono,
    required this.clave,
    required this.valor,
    this.ultima = false,
  });

  final IconData icono;
  final String clave;
  final String valor;
  final bool ultima;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: ultima
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(color: tema.colorScheme.outlineVariant),
              ),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: tema.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(
            width: 104,
            child: Text(clave, style: tema.textTheme.bodySmall),
          ),
          Expanded(
            child: SelectableText(
              valor,
              style: tema.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
