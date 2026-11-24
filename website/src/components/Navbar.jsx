import { useState, useEffect } from 'react';
import { Menu, X, Download } from 'lucide-react';
import { NAV_LINKS, APK_DOWNLOAD_URL } from '../constants';

export default function Navbar() {
  const [isOpen, setIsOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 20);
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  const handleNav = (href) => {
    setIsOpen(false);
    const el = document.querySelector(href);
    if (el) el.scrollIntoView({ behavior: 'smooth' });
  };

  return (
    <header
      className={`fixed top-0 left-0 right-0 z-50 bg-white/95 backdrop-blur-md transition-all duration-300 ${
        scrolled ? 'shadow-md' : ''
      }`}
    >
      <nav className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          {/* Logo */}
          <a
            href="#home"
            onClick={(e) => { e.preventDefault(); handleNav('#home'); }}
            className="flex items-center gap-2 flex-shrink-0"
          >
            <img
              src="/brand/logo-horizontal-red.png"
              alt="MistyGo"
              className="h-8 w-auto"
            />
          </a>

          {/* Desktop Nav */}
          <div className="hidden md:flex items-center gap-1">
            {NAV_LINKS.map((link) => (
              <button
                key={link.href}
                onClick={() => handleNav(link.href)}
                className="px-4 py-2 text-sm font-medium text-gray-600 hover:text-[#C41E34] rounded-lg hover:bg-red-50 transition-all"
              >
                {link.label}
              </button>
            ))}
          </div>

          {/* Download Button */}
          <div className="hidden md:flex">
            <a
              href={APK_DOWNLOAD_URL}
              className="flex items-center gap-2 px-5 py-2 bg-[#C41E34] text-white text-sm font-semibold rounded-full hover:bg-[#9B1728] transition-all shadow-md hover:shadow-lg"
            >
              <Download size={16} />
              Download App
            </a>
          </div>

          {/* Mobile menu button */}
          <button
            onClick={() => setIsOpen(!isOpen)}
            className="md:hidden p-2 rounded-lg text-gray-600 hover:text-[#C41E34] hover:bg-red-50 transition-all"
            aria-label="Toggle menu"
          >
            {isOpen ? <X size={22} /> : <Menu size={22} />}
          </button>
        </div>
      </nav>

      {/* Mobile Menu */}
      <div
        className={`md:hidden overflow-hidden transition-all duration-300 ease-in-out ${
          isOpen ? 'max-h-96 opacity-100' : 'max-h-0 opacity-0'
        }`}
      >
        <div className="bg-white border-t border-gray-100 px-4 py-4 space-y-1">
          {NAV_LINKS.map((link) => (
            <button
              key={link.href}
              onClick={() => handleNav(link.href)}
              className="block w-full text-left px-4 py-3 text-sm font-medium text-gray-700 hover:text-[#C41E34] hover:bg-red-50 rounded-lg transition-all"
            >
              {link.label}
            </button>
          ))}
          <div className="pt-2">
            <a
              href={APK_DOWNLOAD_URL}
              className="flex items-center justify-center gap-2 w-full px-5 py-3 bg-[#C41E34] text-white text-sm font-semibold rounded-full hover:bg-[#9B1728] transition-all"
            >
              <Download size={16} />
              Download App
            </a>
          </div>
        </div>
      </div>
    </header>
  );
}
