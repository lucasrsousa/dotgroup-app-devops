<?php

require __DIR__ . '/../vendor/autoload.php';

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Slim\Factory\AppFactory;
use Monolog\Logger;
use Monolog\Handler\StreamHandler;

// App Slim
$app = AppFactory::create();

// Logger
$log = new Logger('app');
$log->pushHandler(new StreamHandler(__DIR__ . '/../logs/app.log', Logger::DEBUG));

// SQLite init
$dbFile = __DIR__ . '/../data/db.sqlite';
$db = new PDO('sqlite:' . $dbFile);

// Sempre cria a tabela se não existir
$db->exec("CREATE TABLE IF NOT EXISTS tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT,
    done INTEGER
)");

// Garante pelo menos uma task inicial
$count = $db->query("SELECT COUNT(*) FROM tasks")->fetchColumn();
if ($count == 0) {
    $db->exec("INSERT INTO tasks (title, done) VALUES ('Primeira task', 0)");
}

// Rotas
$app->get('/', function (Request $request, Response $response) {
    $response->getBody()->write(json_encode(['message' => 'API rodando!']));
    return $response->withHeader('Content-Type', 'application/json');
});

$app->get('/health', function (Request $request, Response $response) {
    $response->getBody()->write(json_encode(['status' => 'ok']));
    return $response->withHeader('Content-Type', 'application/json');
});

$app->get('/tasks', function (Request $request, Response $response) use ($db) {
    $stmt = $db->query("SELECT * FROM tasks");
    $tasks = $stmt->fetchAll(PDO::FETCH_ASSOC);
    $response->getBody()->write(json_encode($tasks));
    return $response->withHeader('Content-Type', 'application/json');
});

$app->post('/tasks', function (Request $request, Response $response) use ($db, $log) {
    $data = json_decode($request->getBody()->getContents(), true);
    
    if (!isset($data['title']) || empty(trim($data['title']))) {
        $response->getBody()->write(json_encode(['error' => 'O campo title é obrigatório']));
        return $response->withHeader('Content-Type', 'application/json')->withStatus(400);
    }

    $stmt = $db->prepare("INSERT INTO tasks (title, done) VALUES (:title, 0)");
    $stmt->execute([':title' => $data['title']]);
    $log->info("Nova task criada: " . $data['title']);

    $response->getBody()->write(json_encode(['message' => 'Task criada']));
    return $response->withHeader('Content-Type', 'application/json')->withStatus(201);
});

// Rota catch-all para rotas não encontradas
$app->any('/{routes:.+}', function (Request $request, Response $response) {
    $response->getBody()->write(json_encode(['error' => 'Rota não encontrada']));
    return $response->withHeader('Content-Type', 'application/json')->withStatus(404);
});

$app->run();
