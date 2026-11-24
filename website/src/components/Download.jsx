import { Download, Smartphone, Shield, Wifi } from 'lucide-react';
import { APK_DOWNLOAD_URL, APK_VERSION, APK_SIZE, APK_RELEASE_DATE } from '../constants';

export default function DownloadSection() {
  return (
    <section
      id="download"
      className="py-24"
      style={{
        background: 'linear-gradient(135deg, #fff5f6 0%, #ffffff 60%, #fff0f2 100%)',
      }}
    >
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="max-w-3xl mx-auto text-center">
          {/* Badge */}
          <div className="inline-block px-4 py-1.5 bg-red-50 rounded-full mb-4">
            <span className="text-xs font-semibold text-[#C41E34] uppercase tracking-wider">
              Download
            </span>
          </div>

          {/* Heading */}
          <h2 className="text-3xl sm:text-4xl font-extrabold text-gray-900 mb-5">
            Get Started with{' '}
            <span
              style={{
                background: 'linear-gradient(135deg, #C41E34, #F0505F)',
                WebkitBackgroundClip: 'text',
                WebkitTextFillColor: 'transparent',
                backgroundClip: 'text',
              }}
            >
              MistyGo
            </span>
          </h2>

          <p className="text-gray-500 leading-relaxed mb-10 text-base">
            Download the MistyGo Android application and experience a smarter way to manage
            hospitality supplies and food ordering.
          </p>

          {/* Download card */}
          <div className="bg-white rounded-3xl border border-red-100 shadow-xl p-8 mb-8 text-left">
            <div className="flex flex-col sm:flex-row items-start sm:items-center gap-6">
              {/* Android icon */}
              <div
                className="w-20 h-20 rounded-2xl flex items-center justify-center flex-shrink-0 shadow-md"
                style={{ background: 'linear-gradient(135deg, #C41E34, #F0505F)' }}
              >
                <svg viewBox="0 0 24 24" className="w-10 h-10 fill-white">
                  <path d="M17.523 15.341a.75.75 0 1 0 0-1.5.75.75 0 0 0 0 1.5zm-11.046 0a.75.75 0 1 0 0-1.5.75.75 0 0 0 0 1.5zM.5 8.5h23v7a3 3 0 0 1-3 3H3.5a3 3 0 0 1-3-3v-7zm3.293-6.5 2.414-2.414A1 1 0 0 1 7.914 0h8.172a1 1 0 0 1 .707.293L19.207 2H23.5v5H.5V2h3.293zM6.75 14.591a.75.75 0 1 0 0-1.5.75.75 0 0 0 0 1.5zm10.5 0a.75.75 0 1 0 0-1.5.75.75 0 0 0 0 1.5z" />
                </svg>
              </div>

              {/* Info */}
              <div className="flex-1">
                <div className="flex flex-wrap items-center gap-3 mb-2">
                  <h3 className="text-xl font-bold text-gray-900">MistyGo Android</h3>
                  <span className="px-3 py-0.5 bg-red-50 text-[#C41E34] text-xs font-semibold rounded-full border border-red-100">
                    {APK_VERSION}
                  </span>
                </div>
                <div className="flex flex-wrap gap-4 text-sm text-gray-500">
                  <span className="flex items-center gap-1.5">
                    <Smartphone size={14} className="text-[#C41E34]" />
                    Android APK
                  </span>
                  <span className="flex items-center gap-1.5">
                    <Shield size={14} className="text-green-500" />
                    {APK_SIZE}
                  </span>
                  <span className="flex items-center gap-1.5">
                    <Wifi size={14} className="text-blue-500" />
                    Requires internet
                  </span>
                </div>
                <p className="text-xs text-gray-400 mt-1">
                  Released: {APK_RELEASE_DATE} · Beta build for testing
                </p>
              </div>

              {/* Download button */}
              <a
                href={APK_DOWNLOAD_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center gap-2.5 px-7 py-3.5 bg-[#C41E34] text-white font-bold rounded-full hover:bg-[#9B1728] transition-all shadow-lg hover:shadow-xl hover:-translate-y-0.5 text-sm flex-shrink-0 whitespace-nowrap"
              >
                <Download size={18} />
                Download APK
              </a>
            </div>
          </div>

          {/* Install instructions */}
          <div className="bg-amber-50 border border-amber-100 rounded-2xl p-5 text-left">
            <h4 className="font-semibold text-amber-800 mb-3 text-sm">
              📱 How to install the APK on Android
            </h4>
            <ol className="space-y-1.5 text-sm text-amber-700 list-decimal list-inside">
              <li>Download the APK file to your Android device.</li>
              <li>Open your device Settings and enable "Install from Unknown Sources".</li>
              <li>Open the downloaded APK file and tap Install.</li>
              <li>Launch MistyGo and sign in with your credentials.</li>
            </ol>
            <p className="text-xs text-amber-500 mt-3">
              Note: This is a beta build. Internet connectivity is required.
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}
