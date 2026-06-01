# GitHub Pages Deployment Guide

This document explains how to deploy the McFind website to GitHub Pages.

## What's Been Set Up

### 1. Website (`docs/index.html`)
- Professional landing page with modern design
- Features section with icons and descriptions
- Download links for DMG and PKG installers
- Keyboard shortcuts reference
- Performance metrics section
- Fully responsive design

### 2. Application Icon
- SVG icon with magnifying glass design
- Generated PNG icons for all macOS sizes
- Website favicon and header logo
- Matches macOS Big Sur+ design language

### 3. CI/CD Workflow (`.github/workflows/pages.yml`)
- Automatically deploys on push to master branch
- Can be manually triggered via workflow_dispatch
- Uses latest GitHub Actions for Pages deployment

## Deployment Steps

### Initial Setup

1. **Push the changes to GitHub:**
   ```bash
   git push origin master
   ```

2. **Enable GitHub Pages:**
   - Go to your repository: https://github.com/ntufar/mcfind
   - Click **Settings** → **Pages**
   - Under "Build and deployment":
     - Source should be: **GitHub Actions** (automatically selected)
   - The workflow will run automatically

3. **Wait for deployment:**
   - Go to the **Actions** tab in your repository
   - Watch the "Deploy to GitHub Pages" workflow
   - Takes ~1-2 minutes to complete

4. **Access your website:**
   - Once deployed, your site will be available at:
   - **https://ntufar.github.io/mcfind/**

### Subsequent Deployments

Any push to the `master` branch will automatically trigger a new deployment:

```bash
# Make changes to docs/index.html or other files
git add .
git commit -m "Update website"
git push origin master
```

### Manual Deployment

You can also trigger deployment manually:

1. Go to **Actions** tab
2. Select "Deploy to GitHub Pages" workflow
3. Click "Run workflow"
4. Choose the `master` branch
5. Click "Run workflow" button

## Updating the Website

### Content Updates

Edit `docs/index.html` to update:
- Features
- Download links
- Version numbers
- Screenshots
- Documentation links

### Icon Updates

To update the application icon:

1. Edit `docs/icon.svg` with your preferred SVG editor
2. Run the icon generation script:
   ```bash
   python3 generate_icons_simple.py
   ```
3. Commit and push the changes

### Adding New Pages

1. Create new HTML files in the `docs/` directory
2. Link them from `index.html`
3. Commit and push

Example:
```html
<a href="documentation.html">Documentation</a>
```

## Troubleshooting

### Workflow Fails

Check the Actions tab for error messages:
- **Permission denied**: Check repository settings → Actions → General → Workflow permissions
- **Pages not enabled**: Go to Settings → Pages and verify GitHub Actions is selected

### Site Not Updating

1. Check the Actions tab to ensure workflow completed successfully
2. Clear your browser cache (Cmd+Shift+R on macOS)
3. Wait a few minutes for CDN to update

### 404 Not Found

- Ensure `index.html` exists in the `docs/` directory
- Check that the file is committed and pushed
- Verify the deployment succeeded in the Actions tab

## Custom Domain (Optional)

To use a custom domain:

1. Add a `CNAME` file to the `docs/` directory:
   ```
   echo "mcfind.yourdomain.com" > docs/CNAME
   ```

2. Configure DNS:
   - Add a CNAME record pointing to `ntufar.github.io`

3. Go to Settings → Pages → Custom domain
4. Enter your domain and click Save

## Analytics (Optional)

To add Google Analytics:

1. Get your tracking ID from Google Analytics
2. Add the tracking code to `docs/index.html` in the `<head>` section:
   ```html
   <!-- Google Analytics -->
   <script async src="https://www.googletagmanager.com/gtag/js?id=GA_MEASUREMENT_ID"></script>
   <script>
     window.dataLayer = window.dataLayer || [];
     function gtag(){dataLayer.push(arguments);}
     gtag('js', new Date());
     gtag('config', 'GA_MEASUREMENT_ID');
   </script>
   ```

## Files Reference

| File | Purpose |
|------|---------|
| `docs/index.html` | Main website page |
| `docs/icon.svg` | Website and app icon source |
| `.github/workflows/pages.yml` | GitHub Pages deployment workflow |
| `generate_icons_simple.py` | Generate macOS app icons |
| `ICONS.md` | Icon generation documentation |

## Resources

- [GitHub Pages Documentation](https://docs.github.com/en/pages)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Custom Domain Setup](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site)
