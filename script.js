document.addEventListener('DOMContentLoaded', () => {
    // Reveal animations on scroll using IntersectionObserver for better performance and memory management
    const revealElements = document.querySelectorAll('.section, .project-card, .skills-category');

    // Add reveal class to elements to prepare them
    revealElements.forEach(element => {
        element.classList.add('reveal');
    });

    // Use IntersectionObserver to handle visibility changes efficiently
    // This avoids the overhead of running a function on every single scroll event (memory/CPU protection)
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('active');
                // Optional: Stop observing once revealed to free up resources
                // observer.unobserve(entry.target); 
            }
        });
    }, {
        threshold: 0.15, // Trigger when 15% of the element is visible
        rootMargin: "0px 0px -50px 0px"
    });

    revealElements.forEach(element => {
        observer.observe(element);
    });
});
