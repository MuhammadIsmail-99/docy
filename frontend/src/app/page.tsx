import React from 'react';

export default function Home() {
  return (
    <main className="min-h-screen bg-[#0a0a0a] text-white flex flex-col items-center justify-center p-6 text-center">
      <div className="max-w-4xl w-full space-y-8 animate-in fade-in duration-1000">
        <h1 className="text-6xl md:text-8xl font-bold tracking-tight bg-gradient-to-r from-blue-400 via-indigo-500 to-purple-600 bg-clip-text text-transparent">
          Smart Doctor Connect AI
        </h1>
        
        <p className="text-xl md:text-2xl text-gray-400 max-w-2xl mx-auto leading-relaxed">
          The future of healthcare in Pakistan. Instant connections, AI-driven suggestions, 
          and seamless scheduling.
        </p>

        <div className="flex flex-wrap justify-center gap-4 pt-8">
          <button className="px-8 py-4 bg-blue-600 hover:bg-blue-700 text-white rounded-full font-semibold transition-all hover:scale-105 active:scale-95 shadow-[0_0_20px_rgba(37,99,235,0.4)]">
            Find a Doctor
          </button>
          <button className="px-8 py-4 bg-white/10 hover:bg-white/20 text-white border border-white/20 rounded-full font-semibold transition-all hover:scale-105 active:scale-95 backdrop-blur-sm">
            For Doctors
          </button>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mt-20 text-left">
          {[
            { title: "AI Search", desc: "Symptom-based matching using advanced NLP." },
            { title: "Smart Chat", desc: "24/7 AI agent assistance for lead management." },
            { title: "Easy Booking", desc: "One-click scheduling for physical & online visits." }
          ].map((feature, i) => (
            <div key={i} className="p-6 bg-white/5 border border-white/10 rounded-2xl hover:bg-white/10 transition-colors">
              <h3 className="text-xl font-bold mb-2 text-blue-400">{feature.title}</h3>
              <p className="text-gray-400">{feature.desc}</p>
            </div>
          ))}
        </div>
      </div>
    </main>
  );
}
