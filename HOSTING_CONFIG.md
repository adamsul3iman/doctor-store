# Hosting Configuration for Path URL Strategy

This document explains how to configure your hosting provider to support **clean URLs without the # hash** for your Flutter web app.

## Overview

With Path URL Strategy enabled, your URLs will look like:
- ✅ `drstore.me/product/product-name`
- ✅ `drstore.me/category/beds`
- ✅ `drstore.me/cart`

Instead of:
- ❌ `drstore.me/#/product/product-name`

## Required Configuration

All hosting providers need to be configured to serve `index.html` for **all routes**, letting the Flutter app handle the routing client-side.

---

## 1. Firebase Hosting

File: `firebase.json` (already created in project root)

```bash
# Deploy using Firebase CLI
firebase deploy --only hosting
```

The configuration handles:
- All product URLs: `/product/**` and `/p/**`
- All category URLs: `/category/**`
- All admin URLs: `/admin/**`
- All other app pages
- Proper caching headers for static assets

---

## 2. Netlify

File: `_redirects` (already created in project root)

Options:
- Place `_redirects` file in your `build/web` folder before deploying
- Or use `netlify.toml` configuration

```toml
# Alternative: netlify.toml
[[redirects]]
  from = "/product/*"
  to = "/index.html"
  status = 200

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
```

---

## 3. Vercel

File: `vercel.json` (already created in project root)

Deploy:
```bash
vercel --prod
```

---

## 4. Nginx (Self-hosted/VPS)

Add to your nginx site configuration:

```nginx
server {
    listen 80;
    server_name drstore.me;
    root /var/www/doctor_store/build/web;
    index index.html;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Never cache index.html
    location = /index.html {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    # Serve all routes through index.html (Flutter handles routing)
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

---

## 5. Apache (.htaccess)

Create `.htaccess` in your web root:

```apache
<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteBase /
    
    # Don't rewrite files or directories
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d
    
    # Rewrite everything else to index.html
    RewriteRule ^ index.html [QSA,L]
</IfModule>

# Cache static assets
<IfModule mod_expires.c>
    ExpiresActive On
    ExpiresByType text/css "access plus 1 year"
    ExpiresByType application/javascript "access plus 1 year"
    ExpiresByType image/png "access plus 1 year"
    ExpiresByType image/jpg "access plus 1 year"
    ExpiresByType image/jpeg "access plus 1 year"
    ExpiresByType image/svg+xml "access plus 1 year"
    ExpiresByType image/x-icon "access plus 1 year"
</IfModule>

# Never cache index.html
<Files "index.html">
    <IfModule mod_headers.c>
        Header set Cache-Control "no-cache, no-store, must-revalidate"
    </IfModule>
</Files>
```

---

## 6. Docker + Nginx

Create `Dockerfile`:

```dockerfile
FROM nginx:alpine
COPY build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

---

## Testing Your Configuration

After deployment, verify:

1. **Direct URL access works**: Open `yourdomain.com/product/test-product` directly in browser (not from homepage)
2. **Refresh works**: Refresh the page on any route
3. **Title updates**: Tab title shows product/category name
4. **No 404 errors**: Check browser console for errors

---

## Troubleshooting

### 404 Errors on Refresh
- Hosting provider not configured to serve `index.html` for all routes
- Check rewrite rules are in place

### Title Not Updating
- Check `SeoManager.setTitle()` is called in your screens
- Verify `kIsWeb` check is present

### URLs Still Show #
- Path URL Strategy not enabled in `main.dart`
- Check `SystemChannels.platform.invokeMethod` call exists

---

## Support

For issues with specific hosting providers, refer to their documentation:
- [Firebase Hosting](https://firebase.google.com/docs/hosting/full-config)
- [Netlify Redirects](https://docs.netlify.com/routing/redirects/)
- [Vercel Rewrites](https://vercel.com/docs/configuration#project/rewrites)
