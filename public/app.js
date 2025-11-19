// TinyServe Demo Application

function displayResponse(data) {
    const responseEl = document.getElementById('api-response');
    responseEl.textContent = JSON.stringify(data, null, 2);
}

function displayError(error) {
    const responseEl = document.getElementById('api-response');
    responseEl.textContent = `Error: ${error.message}`;
}

async function testStatus() {
    try {
        const response = await fetch('/api/status');
        const data = await response.json();
        displayResponse(data);
    } catch (error) {
        displayError(error);
    }
}

async function testEcho() {
    try {
        const testData = {
            message: 'Hello from TinyServe!',
            timestamp: new Date().toISOString(),
            random: Math.random()
        };
        
        const response = await fetch('/api/echo', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(testData)
        });
        
        const data = await response.json();
        displayResponse(data);
    } catch (error) {
        displayError(error);
    }
}

// Display welcome message on load
window.addEventListener('DOMContentLoaded', () => {
    const responseEl = document.getElementById('api-response');
    responseEl.textContent = 'Click a button above to test the API endpoints...';
});
