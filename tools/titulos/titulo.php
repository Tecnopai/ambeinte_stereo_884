<?php
// titulo.php - Recibe y entrega el titulo que suena en Ambiente Stereo 88.4.
//
// - El computador de emision lo envia por POST con la cabecera X-Clave.
// - La app y el reproductor web lo leen por GET.
// La direccion de este archivo se configura en Firebase:
// app_config/streaming, campo "titulos_url".
//
// IMPORTANTE: cambia CLAVE por una larga e inventada (la misma del script).

const CLAVE   = 'CAMBIA-ESTA-CLAVE-POR-UNA-LARGA-Y-SECRETA';
const ARCHIVO = __DIR__ . '/ahora_suena.json';

header('Access-Control-Allow-Origin: *');      // para que WordPress lo pueda leer
header('Cache-Control: no-store');
header('Content-Type: application/json; charset=utf-8');

// El script envia el titulo (solo con la clave correcta)
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!hash_equals(CLAVE, $_SERVER['HTTP_X_CLAVE'] ?? '')) {
        http_response_code(403);
        echo '{"ok":false}';
        exit;
    }
    $datos  = json_decode(file_get_contents('php://input'), true);
    $titulo = mb_substr(trim((string)($datos['titulo'] ?? '')), 0, 200);
    $registro = ['titulo' => $titulo, 'actualizado' => time()];

    // Estado del audio que mide el computador de emision escuchando el stream
    // publico (opcional). Lo usa el registro de oyentes para avisar por
    // Telegram si la emisora esta en silencio. Las horas se pasan a la hora
    // de este servidor para no depender del reloj del computador.
    if (isset($datos['audio'])) {
        $audio = in_array($datos['audio'], ['ok', 'silencio', 'sin_dato'], true)
            ? $datos['audio'] : 'sin_dato';
        $hace = (int)($datos['audio_hace'] ?? -1);
        $segundosSilencio = max(0, (int)($datos['silencio_seg'] ?? 0));
        $registro['audio']          = $audio;
        $registro['audio_nivel']    = is_numeric($datos['audio_nivel'] ?? null)
            ? round((float)$datos['audio_nivel'], 1) : null;
        $registro['audio_medido']   = $hace < 0 ? 0 : time() - min($hace, 86400);
        $registro['silencio_desde'] = ($audio === 'silencio' && $segundosSilencio > 0)
            ? time() - $segundosSilencio : 0;
    }

    file_put_contents(ARCHIVO, json_encode($registro, JSON_UNESCAPED_UNICODE), LOCK_EX);
    echo '{"ok":true}';
    exit;
}

// La app y la web lo leen
echo is_file(ARCHIVO) ? file_get_contents(ARCHIVO) : '{"titulo":"","actualizado":0}';
