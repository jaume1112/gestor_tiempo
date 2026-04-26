// Canvas setup
const canvas = document.getElementById('pongCanvas');
const ctx = canvas.getContext('2d');

// Resize canvas for responsive design
function resizeCanvas() {
    const container = canvas.parentElement;
    const maxWidth = Math.min(800, container.clientWidth - 40);
    const ratio = 2;
    
    canvas.width = maxWidth;
    canvas.height = maxWidth / ratio;
}
resizeCanvas();
window.addEventListener('resize', resizeCanvas);

// Game objects
const paddleWidth = 10;
const paddleHeight = canvas.height / 4;
const ballSize = 8;

let playerPaddle = {
    x: 10,
    y: canvas.height / 2 - paddleHeight / 2,
    width: paddleWidth,
    height: paddleHeight,
    speed: 6,
    dy: 0
};

let computerPaddle = {
    x: canvas.width - paddleWidth - 10,
    y: canvas.height / 2 - paddleHeight / 2,
    width: paddleWidth,
    height: paddleHeight,
    speed: 4
};

let ball = {
    x: canvas.width / 2,
    y: canvas.height / 2,
    size: ballSize,
    dx: 5,
    dy: 5,
    maxSpeed: 8
};

let score = {
    player: 0,
    computer: 0
};

let gameRunning = false;
let mouseY = canvas.height / 2;

// Input handling - Mouse
document.addEventListener('mousemove', (e) => {
    const rect = canvas.getBoundingClientRect();
    mouseY = e.clientY - rect.top;
});

// Touch support for mobile/Android
canvas.addEventListener('touchmove', (e) => {
    e.preventDefault();
    const rect = canvas.getBoundingClientRect();
    const touch = e.touches[0];
    mouseY = touch.clientY - rect.top;
}, { passive: false });

// Keyboard controls
document.addEventListener('keydown', (e) => {
    if (e.key === 'ArrowUp' || e.key === 'w' || e.key === 'W') {
        playerPaddle.dy = -playerPaddle.speed;
    }
    if (e.key === 'ArrowDown' || e.key === 's' || e.key === 'S') {
        playerPaddle.dy = playerPaddle.speed;
    }
});

document.addEventListener('keyup', (e) => {
    if (e.key === 'ArrowUp' || e.key === 'w' || e.key === 'W' || 
        e.key === 'ArrowDown' || e.key === 's' || e.key === 'S') {
        playerPaddle.dy = 0;
    }
});

// Button controls
document.getElementById('startBtn').addEventListener('click', () => {
    gameRunning = true;
    resetBall();
});

document.getElementById('resetBtn').addEventListener('click', () => {
    score.player = 0;
    score.computer = 0;
    gameRunning = false;
    resetBall();
    updateScore();
});

// Update player paddle with smooth mouse tracking
function updatePlayerPaddle() {
    const targetY = mouseY - playerPaddle.height / 2;
    playerPaddle.y += (targetY - playerPaddle.y) * 0.15;

    // Boundary checking
    if (playerPaddle.y < 0) playerPaddle.y = 0;
    if (playerPaddle.y + playerPaddle.height > canvas.height) {
        playerPaddle.y = canvas.height - playerPaddle.height;
    }
}

// Computer AI with smart difficulty
function updateComputerPaddle() {
    const computerCenter = computerPaddle.y + computerPaddle.height / 2;
    const ballCenter = ball.y;

    // AI movement with dead zone (makes it beatable)
    if (computerCenter < ballCenter - 35) {
        computerPaddle.y += computerPaddle.speed;
    } else if (computerCenter > ballCenter + 35) {
        computerPaddle.y -= computerPaddle.speed;
    }

    // Boundary checking
    if (computerPaddle.y < 0) computerPaddle.y = 0;
    if (computerPaddle.y + computerPaddle.height > canvas.height) {
        computerPaddle.y = canvas.height - computerPaddle.height;
    }
}

// Update ball physics
function updateBall() {
    ball.x += ball.dx;
    ball.y += ball.dy;

    // Top and bottom wall collision
    if (ball.y - ball.size < 0 || ball.y + ball.size > canvas.height) {
        ball.dy = -ball.dy;
        ball.y = ball.y - ball.size < 0 ? ball.size : canvas.height - ball.size;
    }

    // Paddle collision detection
    if (checkPaddleCollision(playerPaddle)) {
        ball.dx = Math.abs(ball.dx);
        ball.x = playerPaddle.x + playerPaddle.width + ball.size;
        addSpinToPaddle(playerPaddle);
    }

    if (checkPaddleCollision(computerPaddle)) {
        ball.dx = -Math.abs(ball.dx);
        ball.x = computerPaddle.x - ball.size;
        addSpinToPaddle(computerPaddle);
    }

    // Scoring
    if (ball.x - ball.size < 0) {
        score.computer++;
        updateScore();
        resetBall();
    }

    if (ball.x + ball.size > canvas.width) {
        score.player++;
        updateScore();
        resetBall();
    }
}

// Check collision between ball and paddle
function checkPaddleCollision(paddle) {
    return ball.x + ball.size > paddle.x &&
           ball.x - ball.size < paddle.x + paddle.width &&
           ball.y + ball.size > paddle.y &&
           ball.y - ball.size < paddle.y + paddle.height;
}

// Add spin to ball based on paddle hit location
function addSpinToPaddle(paddle) {
    const paddleCenter = paddle.y + paddle.height / 2;
    const ballCenter = ball.y;
    const distanceFromCenter = ballCenter - paddleCenter;
    const maxSpin = 4;

    ball.dy += (distanceFromCenter / (paddle.height / 2)) * maxSpin;
    ball.dy = Math.max(-ball.maxSpeed, Math.min(ball.maxSpeed, ball.dy));

    // Increase ball speed slightly on each hit
    ball.dx *= 1.02;
    ball.dx = Math.max(-ball.maxSpeed, Math.min(ball.maxSpeed, ball.dx));
}

// Reset ball to center
function resetBall() {
    ball.x = canvas.width / 2;
    ball.y = canvas.height / 2;
    ball.dx = (Math.random() > 0.5 ? 1 : -1) * 5;
    ball.dy = (Math.random() - 0.5) * 5;
}

// Update score display
function updateScore() {
    document.getElementById('playerScore').textContent = score.player;
    document.getElementById('computerScore').textContent = score.computer;
}

// Draw paddle
function drawPaddle(paddle) {
    ctx.fillStyle = '#00ffff';
    ctx.shadowColor = '#00ffff';
    ctx.shadowBlur = 10;
    ctx.fillRect(paddle.x, paddle.y, paddle.width, paddle.height);
    ctx.shadowBlur = 0;
}

// Draw ball
function drawBall() {
    ctx.fillStyle = '#ffff00';
    ctx.shadowColor = '#ffff00';
    ctx.shadowBlur = 10;
    ctx.beginPath();
    ctx.arc(ball.x, ball.y, ball.size, 0, Math.PI * 2);
    ctx.fill();
    ctx.shadowBlur = 0;
}

// Draw center line
function drawCenterLine() {
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.3)';
    ctx.setLineDash([10, 10]);
    ctx.beginPath();
    ctx.moveTo(canvas.width / 2, 0);
    ctx.lineTo(canvas.width / 2, canvas.height);
    ctx.stroke();
    ctx.setLineDash([]);
}

// Main game loop
function gameLoop() {
    // Clear canvas
    ctx.fillStyle = '#000';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    // Draw game elements
    drawCenterLine();
    drawPaddle(playerPaddle);
    drawPaddle(computerPaddle);
    drawBall();

    // Update game logic when running
    if (gameRunning) {
        updatePlayerPaddle();
        updateComputerPaddle();
        updateBall();
    }

    requestAnimationFrame(gameLoop);
}

// Start the game loop
gameLoop();

// Handle window resize for responsive canvas
window.addEventListener('resize', () => {
    resizeCanvas();
});
