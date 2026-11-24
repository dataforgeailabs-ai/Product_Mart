import Navbar from './components/Navbar';
import Hero from './components/Hero';
import About from './components/About';
import Features from './components/Features';
import HowItWorks from './components/HowItWorks';
import WhoCanUse from './components/WhoCanUse';
import AppPreview from './components/AppPreview';
import DownloadSection from './components/Download';
import Contact from './components/Contact';
import Footer from './components/Footer';

export default function App() {
  return (
    <div className="min-h-screen">
      <Navbar />
      <main>
        <Hero />
        <About />
        <Features />
        <HowItWorks />
        <WhoCanUse />
        <AppPreview />
        <DownloadSection />
        <Contact />
      </main>
      <Footer />
    </div>
  );
}
