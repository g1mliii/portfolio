document.addEventListener('DOMContentLoaded', () => {
    // Reveal animations on scroll
    const revealElements = document.querySelectorAll('.section, .project-card, .skills-category');

    // Add reveal class to elements
    revealElements.forEach(element => {
        element.classList.add('reveal');
    });

    const revealOnScroll = () => {
        const windowHeight = window.innerHeight;
        const elementVisible = 30;

        revealElements.forEach((element) => {
            const elementTop = element.getBoundingClientRect().top;

            if (elementTop < windowHeight - elementVisible) {
                element.classList.add('active');
            }
        });
    };

    window.addEventListener('scroll', revealOnScroll);
    // Trigger once on load
    revealOnScroll();
});
