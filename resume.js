document.addEventListener('DOMContentLoaded', () => {
    const printBtn = document.querySelector('.print-button');
    if (printBtn) {
        printBtn.addEventListener('click', () => {
            window.print();
        });
    }
});
