import {
  Download,
  UserPlus,
  Search,
  PackageCheck,
} from 'lucide-react';
import { HOW_IT_WORKS } from '../constants';

const iconMap = { Download, UserPlus, Search, PackageCheck };

export default function HowItWorks() {
  return (
    <section id="how-it-works" className="py-24 bg-white">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Section header */}
        <div className="text-center max-w-2xl mx-auto mb-16">
          <div className="inline-block px-4 py-1.5 bg-red-50 rounded-full mb-4">
            <span className="text-xs font-semibold text-[#C41E34] uppercase tracking-wider">
              How It Works
            </span>
          </div>
          <h2 className="text-3xl sm:text-4xl font-extrabold text-gray-900 mb-4">
            Get Started in{' '}
            <span
              style={{
                background: 'linear-gradient(135deg, #C41E34, #F0505F)',
                WebkitBackgroundClip: 'text',
                WebkitTextFillColor: 'transparent',
                backgroundClip: 'text',
              }}
            >
              Four Simple Steps
            </span>
          </h2>
          <p className="text-gray-500 leading-relaxed">
            From download to your first order — getting started with MistyGo is quick and easy.
          </p>
        </div>

        {/* Steps */}
        <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-8">
          {HOW_IT_WORKS.map((item, index) => {
            const Icon = iconMap[item.icon];
            const isLast = index === HOW_IT_WORKS.length - 1;
            return (
              <div key={item.step} className="relative flex flex-col items-center text-center">
                {/* Connector */}
                {!isLast && (
                  <div className="hidden lg:block absolute top-10 left-[calc(50%+2.5rem)] right-[-calc(50%-2.5rem)] h-0.5 bg-gradient-to-r from-red-200 to-transparent z-0" />
                )}

                {/* Step number & icon */}
                <div className="relative z-10 mb-5">
                  <div className="w-20 h-20 bg-white rounded-2xl border-2 border-red-100 shadow-md flex items-center justify-center mb-2 mx-auto">
                    {Icon && <Icon size={28} className="text-[#C41E34]" />}
                  </div>
                  <div
                    className="absolute -top-2 -right-2 w-6 h-6 rounded-full text-white text-xs font-bold flex items-center justify-center shadow-sm"
                    style={{ background: '#C41E34' }}
                  >
                    {item.step}
                  </div>
                </div>

                <h3 className="font-bold text-gray-900 mb-2 text-base">{item.title}</h3>
                <p className="text-gray-500 text-sm leading-relaxed">{item.description}</p>
              </div>
            );
          })}
        </div>

        {/* CTA ribbon */}
        <div
          className="mt-16 rounded-2xl p-8 text-center"
          style={{
            background: 'linear-gradient(135deg, #C41E34, #F0505F)',
          }}
        >
          <h3 className="text-2xl font-bold text-white mb-3">Ready to get started?</h3>
          <p className="text-red-100 mb-6 text-sm">
            Download MistyGo today and transform the way you manage your hospitality business.
          </p>
          <a
            href="#download"
            onClick={(e) => {
              e.preventDefault();
              document.querySelector('#download')?.scrollIntoView({ behavior: 'smooth' });
            }}
            className="inline-flex items-center gap-2 px-8 py-3.5 bg-white text-[#C41E34] font-bold rounded-full hover:bg-red-50 transition-all shadow-lg text-sm"
          >
            <Download size={18} />
            Download Free APK
          </a>
        </div>
      </div>
    </section>
  );
}
