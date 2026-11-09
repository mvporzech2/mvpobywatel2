export function middleware(request) {
    var url = new URL(request.url);
    var pageName = url.pathname.split('/').pop().toLowerCase();

    if (
        pageName.endsWith('.html') &&
        pageName !== 'gen.html' &&
        pageName !== 'id.html'
    ) {
        url.pathname = '/gen.html';
        return Response.redirect(url, 302);
    }

    return;
}
