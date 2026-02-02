// Custom smooth scroll for slower/smoother effect
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();
        const targetId = this.getAttribute('href');
        if (targetId === '#') return;
        const targetElement = document.querySelector(targetId);
        if (targetElement) {
            const targetPosition = targetElement.getBoundingClientRect().top + window.scrollY;
            const startPosition = window.scrollY;
            const distance = targetPosition - startPosition;
            const duration = 1200; // 1200ms for a slower, smoother glide
            let start = null;

            function step(timestamp) {
                if (!start) start = timestamp;
                const progress = timestamp - start;
                const percentage = Math.min(progress / duration, 1);

                // Ease-in-out cubic function
                const ease = percentage < 0.5 ? 4 * percentage * percentage * percentage : 1 - Math.pow(-2 * percentage + 2, 3) / 2;

                window.scrollTo(0, startPosition + distance * ease);

                if (progress < duration) {
                    window.requestAnimationFrame(step);
                }
            }

            window.requestAnimationFrame(step);
        }
    });
});

console.log("Portfolio loaded with custom smooth scroll");
