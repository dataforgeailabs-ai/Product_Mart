import { useState } from 'react';
import { Mail, MessageSquare, Send } from 'lucide-react';

export default function Contact() {
  const [form, setForm] = useState({ name: '', email: '', subject: '', message: '' });
  const [submitted, setSubmitted] = useState(false);

  const handleChange = (e) => {
    setForm((prev) => ({ ...prev, [e.target.name]: e.target.value }));
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    // Build mailto link with form data
    const subject = encodeURIComponent(form.subject || 'MistyGo Enquiry');
    const body = encodeURIComponent(
      `Name: ${form.name}\nEmail: ${form.email}\n\n${form.message}`
    );
    window.location.href = `mailto:support@mistygo.app?subject=${subject}&body=${body}`;
    setSubmitted(true);
  };

  return (
    <section id="contact" className="py-24 bg-white">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid lg:grid-cols-2 gap-16 items-start">
          {/* Left: Info */}
          <div>
            <div className="inline-block px-4 py-1.5 bg-red-50 rounded-full mb-4">
              <span className="text-xs font-semibold text-[#C41E34] uppercase tracking-wider">
                Contact
              </span>
            </div>
            <h2 className="text-3xl sm:text-4xl font-extrabold text-gray-900 mb-5">
              Get in Touch
            </h2>
            <p className="text-gray-500 leading-relaxed mb-8">
              Have questions about MistyGo? Want to partner with us or report an issue?
              Fill in the form and we will get back to you.
            </p>

            <div className="space-y-5">
              <div className="flex items-start gap-4">
                <div className="w-11 h-11 bg-red-50 rounded-xl flex items-center justify-center flex-shrink-0">
                  <Mail size={20} className="text-[#C41E34]" />
                </div>
                <div>
                  <p className="font-semibold text-gray-800 text-sm">Email</p>
                  <p className="text-gray-500 text-sm">support@mistygo.app</p>
                </div>
              </div>

              <div className="flex items-start gap-4">
                <div className="w-11 h-11 bg-red-50 rounded-xl flex items-center justify-center flex-shrink-0">
                  <MessageSquare size={20} className="text-[#C41E34]" />
                </div>
                <div>
                  <p className="font-semibold text-gray-800 text-sm">Support</p>
                  <p className="text-gray-500 text-sm">Use the form to send us a message directly.</p>
                </div>
              </div>
            </div>

            {/* GitHub link */}
            <div className="mt-8 p-5 bg-gray-50 rounded-2xl border border-gray-100">
              <p className="text-sm font-semibold text-gray-700 mb-2">Open Source</p>
              <p className="text-xs text-gray-500 mb-3">
                MistyGo is available on GitHub. Report bugs, follow development and download releases.
              </p>
              <a
                href="https://github.com/dataforgeailabs-ai/Product_Mart"
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-2 text-xs font-semibold text-gray-700 hover:text-[#C41E34] transition-colors"
              >
                <svg viewBox="0 0 24 24" className="w-4 h-4 fill-current">
                  <path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12" />
                </svg>
                View on GitHub
              </a>
            </div>
          </div>

          {/* Right: Form */}
          <div className="bg-white rounded-3xl border border-gray-100 shadow-lg p-8">
            {submitted ? (
              <div className="text-center py-8">
                <div className="w-16 h-16 bg-green-50 rounded-full flex items-center justify-center mx-auto mb-4">
                  <svg viewBox="0 0 24 24" className="w-8 h-8 text-green-500 fill-current">
                    <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z" />
                  </svg>
                </div>
                <h3 className="text-xl font-bold text-gray-900 mb-2">Message Sent!</h3>
                <p className="text-gray-500 text-sm">Your email client should have opened. Thank you for reaching out.</p>
                <button
                  onClick={() => setSubmitted(false)}
                  className="mt-5 text-sm text-[#C41E34] font-medium hover:underline"
                >
                  Send another message
                </button>
              </div>
            ) : (
              <form onSubmit={handleSubmit} className="space-y-5">
                <div className="grid sm:grid-cols-2 gap-5">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1.5">
                      Name <span className="text-red-400">*</span>
                    </label>
                    <input
                      name="name"
                      value={form.name}
                      onChange={handleChange}
                      required
                      placeholder="Your name"
                      className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:border-[#C41E34] focus:outline-none focus:ring-2 focus:ring-red-100 text-sm transition-all"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1.5">
                      Email <span className="text-red-400">*</span>
                    </label>
                    <input
                      name="email"
                      type="email"
                      value={form.email}
                      onChange={handleChange}
                      required
                      placeholder="you@example.com"
                      className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:border-[#C41E34] focus:outline-none focus:ring-2 focus:ring-red-100 text-sm transition-all"
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1.5">Subject</label>
                  <input
                    name="subject"
                    value={form.subject}
                    onChange={handleChange}
                    placeholder="How can we help?"
                    className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:border-[#C41E34] focus:outline-none focus:ring-2 focus:ring-red-100 text-sm transition-all"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1.5">
                    Message <span className="text-red-400">*</span>
                  </label>
                  <textarea
                    name="message"
                    value={form.message}
                    onChange={handleChange}
                    required
                    rows={5}
                    placeholder="Tell us more..."
                    className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:border-[#C41E34] focus:outline-none focus:ring-2 focus:ring-red-100 text-sm transition-all resize-none"
                  />
                </div>

                <button
                  type="submit"
                  className="flex items-center justify-center gap-2 w-full py-3.5 bg-[#C41E34] text-white font-bold rounded-full hover:bg-[#9B1728] transition-all shadow-md hover:shadow-lg text-sm"
                >
                  <Send size={16} />
                  Send Message
                </button>
              </form>
            )}
          </div>
        </div>
      </div>
    </section>
  );
}
