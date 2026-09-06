import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../estado/ambito_atlas.dart';
import '../modelos/respuesta_api.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnóstico de conexión')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Configuración del entorno',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _Fila('API_BASE_URL', AppConfig.apiBaseUrl),
                  _Fila('APP_ENV', AppConfig.entorno),
                  _Fila('Timeout', '${AppConfig.timeout.inSeconds} s'),
                  if (AppConfig.usaTraficoSinCifrar) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Tráfico sin cifrar (http) autorizado únicamente para el '
                      'host de desarrollo declarado en network_security_config.xml. '
                      'Esta excepción debe eliminarse antes de cualquier '
                      'distribución de la aplicación.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _cargando ? null : _probar,
            icon: _cargando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.network_check),
            label: const Text('Probar conexión con la API'),
          ),
          const SizedBox(height: 16),
          ?_resultado,
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila(this.clave, this.valor);

  final String clave;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(clave,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          Expanded(
              child: SelectableText(valor, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
