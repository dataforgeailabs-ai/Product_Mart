import { Download } from 'lucide-react';
import { NAV_LINKS, APK_DOWNLOAD_URL, GITHUB_REPO_URL } from '../constants';

export default function Footer() {
  const year = new Date().getFullYear();

  const handleNav = (href) => {
    const el = document.querySelector(href);
    if (el) el.scrollIntoView({ behavior: 'smooth' });
  };

  return (
    <footer
      className="pt-16 pb-8"
      style={{ background: '#1a1a2e' }}
    >
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-10 pb-12 border-b border-white/10">
          {/* Brand column */}
          <div className="md:col-span-1">
            <img
              src="/brand/logo-horizontal-white.png"
              alt="MistyGo"
              className="h-9 w-auto mb-4"
            />
            <p className="text-gray-400 text-sm leading-relaxed mb-5">
              MistyGo is a hospitality-focused platform connecting hotels, resorts,
              restaurants and delivery operations through one unified Android app.
            </p>
            {/* GitHub link */}
            <a
              href={GITHUB_REPO_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2 text-gray-400 hover:text-white transition-colors text-sm"
            >
              <svg viewBox="0 0 24 24" className="w-4 h-4 fill-current">
                <path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12" />
              </svg>
              GitHub Repository
            </a>
          </div>

          {/* Navigation links */}
          <div>
            <h4 className="text-white font-semibold mb-5 text-sm">Navigation</h4>
            <ul className="space-y-3">
              {NAV_LINKS.map((link) => (
                <li key={link.href}>
                  <button
                    onClick={() => handleNav(link.href)}
                    className="text-gray-400 hover:text-white text-sm transition-colors"
                  >
                    {link.label}
                  </button>
                </li>
              ))}
            </ul>
          </div>

          {/* Download column */}
          <div>
            <h4 className="text-white font-semibold mb-5 text-sm">Download</h4>
            <p className="text-gray-400 text-sm mb-5">
              MistyGo is available as a free Android APK download from GitHub Releases.
            </p>
            <a
              href={APK_DOWNLOAD_URL}
              className="inline-flex items-center gap-2 px-6 py-3 bg-[#C41E34] text-white text-sm font-semibold rounded-full hover:bg-[#9B1728] transition-all shadow-md"
            >
              <Download size={16} />
              Download for Android
            </a>
          </div>
        </div>

        {/* Bottom bar */}
        <div className="pt-8 flex flex-col sm:flex-row items-center justify-between gap-4">
          <p className="text-gray-500 text-xs">
            &copy; {year} MistyGo. All rights reserved.
          </p>
          <p className="text-gray-600 text-xs">
            Built with React &amp; Tailwind CSS
          </p>
        </div>
      </div>
    </footer>
  );
}
