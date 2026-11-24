import { Download, ChevronDown } from 'lucide-react';
import { APK_DOWNLOAD_URL } from '../constants';

export default function Hero() {
  const handleExplore = () => {
    document.querySelector('#features')?.scrollIntoView({ behavior: 'smooth' });
  };

  return (
    <section
      id="home"
      className="relative min-h-screen flex items-center overflow-hidden pt-16"
      style={{
        background: 'linear-gradient(135deg, #fff5f6 0%, #ffffff 50%, #fff0f2 100%)',
      }}
    >
      {/* Background decorative circles */}
      <div
        className="absolute top-0 right-0 w-96 h-96 rounded-full opacity-10 pointer-events-none"
        style={{ background: 'radial-gradient(circle, #C41E34, transparent)', transform: 'translate(30%, -30%)' }}
      />
      <div
        className="absolute bottom-0 left-0 w-72 h-72 rounded-full opacity-8 pointer-events-none"
        style={{ background: 'radial-gradient(circle, #F0505F, transparent)', transform: 'translate(-40%, 40%)' }}
      />
      <div
        className="absolute top-1/2 left-1/3 w-48 h-48 rounded-full opacity-5 pointer-events-none"
        style={{ background: 'radial-gradient(circle, #C41E34, transparent)' }}
      />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20 w-full">
        <div className="grid lg:grid-cols-2 gap-12 items-center">
          {/* Left: Content */}
          <div className="text-center lg:text-left">
            {/* Badge */}
            <div className="inline-flex items-center gap-2 px-4 py-1.5 bg-red-50 border border-red-100 rounded-full mb-6">
              <span className="w-2 h-2 bg-[#C41E34] rounded-full animate-pulse" />
              <span className="text-xs font-semibold text-[#C41E34] uppercase tracking-wide">
                Now Available for Android
              </span>
            </div>

            {/* Heading */}
            <h1 className="text-4xl sm:text-5xl lg:text-6xl font-extrabold text-gray-900 leading-tight mb-6">
              Everything Your{' '}
              <span
                className="gradient-text"
                style={{
                  background: 'linear-gradient(135deg, #C41E34, #F0505F)',
                  WebkitBackgroundClip: 'text',
                  WebkitTextFillColor: 'transparent',
                  backgroundClip: 'text',
                }}
              >
                Hospitality Business
              </span>{' '}
              Needs, In One Platform.
            </h1>

            {/* Subtext */}
            <p className="text-lg text-gray-500 leading-relaxed mb-8 max-w-xl mx-auto lg:mx-0">
              Discover MistyGo – a smarter way for hotels, resorts and restaurants to manage
              supplies, food ordering and deliveries.
            </p>

            {/* CTA Buttons */}
            <div className="flex flex-col sm:flex-row gap-4 justify-center lg:justify-start">
              <a
                href={APK_DOWNLOAD_URL}
                className="flex items-center justify-center gap-2.5 px-8 py-4 bg-[#C41E34] text-white font-semibold rounded-full hover:bg-[#9B1728] transition-all shadow-lg hover:shadow-xl hover:-translate-y-0.5 text-base"
              >
                <Download size={20} />
                Download for Android
              </a>
              <button
                onClick={handleExplore}
                className="flex items-center justify-center gap-2 px-8 py-4 border-2 border-[#C41E34] text-[#C41E34] font-semibold rounded-full hover:bg-red-50 transition-all text-base"
              >
                Explore Features
                <ChevronDown size={18} />
              </button>
            </div>

            {/* Trust badges */}
            <div className="flex flex-wrap gap-6 mt-10 justify-center lg:justify-start">
              <div className="flex items-center gap-2 text-sm text-gray-500">
                <svg viewBox="0 0 24 24" className="w-5 h-5 text-green-500 fill-current">
                  <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z" />
                </svg>
                Free to Download
              </div>
              <div className="flex items-center gap-2 text-sm text-gray-500">
                <svg viewBox="0 0 24 24" className="w-5 h-5 text-green-500 fill-current">
                  <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z" />
                </svg>
                Android APK
              </div>
              <div className="flex items-center gap-2 text-sm text-gray-500">
                <svg viewBox="0 0 24 24" className="w-5 h-5 text-green-500 fill-current">
                  <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z" />
                </svg>
                Secure Payments
              </div>
            </div>
          </div>

          {/* Right: Phone Mockup */}
          <div className="flex justify-center lg:justify-end">
            <PhoneMockup />
          </div>
        </div>
      </div>

      {/* Scroll indicator */}
      <div className="absolute bottom-8 left-1/2 -translate-x-1/2 flex flex-col items-center gap-1 opacity-50">
        <span className="text-xs text-gray-400">Scroll to explore</span>
        <ChevronDown size={18} className="text-[#C41E34] animate-bounce" />
      </div>
    </section>
  );
}

function PhoneMockup() {
  return (
    <div className="relative">
      {/* Glow effect */}
      <div
        className="absolute inset-0 rounded-[44px] pointer-events-none"
        style={{
          background: 'radial-gradient(ellipse at center, rgba(196,30,52,0.2), transparent 70%)',
          transform: 'scale(1.3)',
          filter: 'blur(24px)',
        }}
      />

      {/* Phone outer frame */}
      <div
        className="relative w-64 sm:w-72 mx-auto"
        style={{
          filter: 'drop-shadow(0 32px 64px rgba(196,30,52,0.2))',
        }}
      >
        <div
          className="bg-gray-900 rounded-[44px] p-3 shadow-2xl"
          style={{ border: '8px solid #1a1a2e' }}
        >
          {/* Notch */}
          <div className="bg-black rounded-t-[36px] rounded-b-sm h-6 flex items-center justify-center mb-0.5">
            <div className="w-20 h-4 bg-gray-900 rounded-full" />
          </div>

          {/* Screen content */}
          <div
            className="rounded-[28px] overflow-hidden"
            style={{ aspectRatio: '9/19', background: '#FFFBFB' }}
          >
            {/* App Bar */}
            <div className="bg-[#C41E34] px-4 py-3 flex items-center justify-between">
              <img
                src="/brand/logo-horizontal-white.png"
                alt="MistyGo"
                className="h-5 w-auto"
              />
              <div className="w-6 h-6 bg-white/20 rounded-full" />
            </div>

            {/* App content preview */}
            <div className="p-3 space-y-3">
              {/* Category chips */}
              <div className="flex gap-2 overflow-hidden">
                {['All', 'Supplies', 'Food'].map((cat, i) => (
                  <div
                    key={cat}
                    className={`px-3 py-1 rounded-full text-xs font-medium flex-shrink-0 ${
                      i === 0
                        ? 'bg-[#C41E34] text-white'
                        : 'bg-gray-100 text-gray-500'
                    }`}
                  >
                    {cat}
                  </div>
                ))}
              </div>

              {/* Product cards */}
              {[
                { name: 'Hotel Linen Set', price: '₹1,200', emoji: '🛏️' },
                { name: 'Biryani (Full)', price: '₹350', emoji: '🍛' },
                { name: 'Toiletry Kit', price: '₹480', emoji: '🧴' },
              ].map((item) => (
                <div
                  key={item.name}
                  className="bg-white rounded-xl p-2.5 flex items-center gap-2.5 shadow-sm border border-gray-50"
                >
                  <div className="w-10 h-10 bg-red-50 rounded-lg flex items-center justify-center text-lg flex-shrink-0">
                    {item.emoji}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="text-xs font-semibold text-gray-800 truncate">{item.name}</div>
                    <div className="text-xs text-[#C41E34] font-bold">{item.price}</div>
                  </div>
                  <div className="w-6 h-6 bg-[#C41E34] rounded-full flex items-center justify-center flex-shrink-0">
                    <span className="text-white text-xs font-bold">+</span>
                  </div>
                </div>
              ))}

              {/* Bottom Nav */}
              <div className="border-t border-gray-100 pt-2 flex justify-around">
                {['🏠', '🛒', '📋', '👤'].map((icon, i) => (
                  <div
                    key={i}
                    className={`flex flex-col items-center gap-0.5 ${
                      i === 0 ? 'text-[#C41E34]' : 'text-gray-300'
                    }`}
                  >
                    <span className="text-sm">{icon}</span>
                    <div
                      className={`w-4 h-0.5 rounded-full ${
                        i === 0 ? 'bg-[#C41E34]' : 'bg-transparent'
                      }`}
                    />
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Home indicator */}
          <div className="flex justify-center mt-2">
            <div className="w-16 h-1 bg-gray-600 rounded-full" />
          </div>
        </div>
      </div>
    </div>
  );
}
