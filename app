import React, { useState, useEffect, useRef } from 'react';
import { Scale, FileText, Link as LinkIcon, Search, AlertCircle, Copy, Check, BookOpen, Folder, FileDown, PanelLeftClose, PanelLeftOpen, FileCode2, Tag, Plus, X, MessageCircle, Send, Bot, User, Highlighter, PenTool, Maximize, Minimize, ChevronDown, ChevronRight, Home, PlusCircle, Minus, Sparkles, Trash2, Eraser, Loader2, Layers, Printer } from 'lucide-react';

// API Key is provided by the execution environment
const apiKey = "";

const fetchWithRetry = async (url, options, retries = 5) => {
  const delays = [1000, 2000, 4000, 8000, 16000];
  for (let i = 0; i < retries; i++) {
    try {
      const response = await fetch(url, options);
      if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
      return await response.json();
    } catch (error) {
      if (i === retries - 1) throw error;
      await new Promise(resolve => setTimeout(resolve, delays[i]));
    }
  }
};

// Markdown to HTML parser for AI output
const parseText = (text) => {
  if (!text) return { __html: '' };
  const html = text
    .replace(/</g, "&lt;").replace(/>/g, "&gt;") // Sanitize
    .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>') // Bold
    .replace(/\n/g, '<br/>'); // Newlines
  return { __html: html };
};

// Unified Table Generator for Docs/PDF Export
const generateCaseTableHtml = (digest) => {
  const ratioHtml = digest.ratio_per_issue?.map(r => `<p style="margin-top:0; margin-bottom:8px;"><strong>${r.issue_reference}</strong><br/>${parseText(r.ratio).__html}</p>`).join('') || '';
  
  return `
    <table style="width: 100%; border-collapse: collapse; border: 1px solid #000000; font-family: 'Google Sans', sans-serif; font-size: 8pt; margin-bottom: 40px; text-align: justify; line-height: 1.5; color: #000000;">
      <tbody>
        <tr><th style="width: 20%; padding: 8px; border: 1px solid #000000; text-align: left; background-color: #f3f4f6; vertical-align: top;">CASE TITLE</th><td style="width: 80%; padding: 8px; border: 1px solid #000000; vertical-align: top;"><strong>${digest.title}</strong></td></tr>
        <tr><th style="width: 20%; padding: 8px; border: 1px solid #000000; text-align: left; background-color: #f3f4f6; vertical-align: top;">G.R. NO. & DATE</th><td style="width: 80%; padding: 8px; border: 1px solid #000000; vertical-align: top;">${digest.gr_no || 'N/A'} • ${digest.date || 'N/A'}</td></tr>
        <tr><th style="width: 20%; padding: 8px; border: 1px solid #000000; text-align: left; background-color: #f3f4f6; vertical-align: top;">FACTS</th><td style="width: 80%; padding: 8px; border: 1px solid #000000; text-align: justify; vertical-align: top;">${parseText(digest.facts).__html} ${digest.ruling_lower_courts?.map(lc => `<p style="margin-top:8px; margin-bottom:0;"><strong>${lc.court}:</strong> ${parseText(lc.ruling).__html}</p>`).join('')}</td></tr>
        <tr><th style="width: 20%; padding: 8px; border: 1px solid #000000; text-align: left; background-color: #f3f4f6; vertical-align: top;">ISSUE(S)</th><td style="width: 80%; padding: 8px; border: 1px solid #000000; vertical-align: top;"><ol style="margin-top: 0; margin-bottom: 0; padding-left: 20px;">${digest.issues?.map(i => `<li style="margin-bottom: 6px;">${parseText(i).__html}</li>`).join('')}</ol></td></tr>
        <tr><th style="width: 20%; padding: 8px; border: 1px solid #000000; text-align: left; background-color: #f3f4f6; vertical-align: top;">RULING</th><td style="width: 80%; padding: 8px; border: 1px solid #000000; vertical-align: top;">${digest.ruling_per_issue?.map(r => `<p style="margin-top:0; margin-bottom:8px;"><strong>${r.issue_reference}</strong> ${parseText(r.ruling).__html}</p>`).join('')}</td></tr>
        <tr><th style="width: 20%; padding: 8px; border: 1px solid #000000; text-align: left; background-color: #f3f4f6; vertical-align: top;">RATIO</th><td style="width: 80%; padding: 8px; border: 1px solid #000000; text-align: justify; vertical-align: top;">${ratioHtml}</td></tr>
        <tr><th style="width: 20%; padding: 8px; border: 1px solid #000000; text-align: left; background-color: #f3f4f6; vertical-align: top;">DISPOSITIVE</th><td style="width: 80%; padding: 8px; border: 1px solid #000000; font-style: italic; vertical-align: top;">${parseText(digest.dispositive_portion).__html}</td></tr>
        <tr><th style="width: 20%; padding: 8px; border: 1px solid #000000; text-align: left; background-color: #f3f4f6; vertical-align: top;">DOCTRINES</th><td style="width: 80%; padding: 8px; border: 1px solid #000000; text-align: justify; vertical-align: top;"><ul style="margin-top: 0; margin-bottom: 0; padding-left: 20px;">${digest.doctrines?.map(d => `<li style="margin-bottom: 6px;">${parseText(d).__html}</li>`).join('')}</ul></td></tr>
        ${digest.personal_notes ? `<tr><th style="width: 20%; padding: 8px; border: 1px solid #000000; text-align: left; background-color: #f3f4f6; vertical-align: top;">PERSONAL NOTES</th><td style="width: 80%; padding: 8px; border: 1px solid #000000; text-align: justify; white-space: pre-wrap; vertical-align: top; font-family: 'Google Sans', sans-serif;">${digest.personal_notes}</td></tr>` : ''}
      </tbody>
    </table>
    <br style="page-break-after: always; clear: both;" />
  `;
};

export default function App() {
  const [inputType, setInputType] = useState('url');
  const [inputValue, setInputValue] = useState('');
  const [isProcessing, setIsProcessing] = useState(false);
  const [error, setError] = useState(null);
  const [currentDigest, setCurrentDigest] = useState(null);
  const [history, setHistory] = useState([]);
  const [copiedSection, setCopiedSection] = useState(null);
  const [showWelcome, setShowWelcome] = useState(true);
  const [showUpdates, setShowUpdates] = useState(false);
  const [subject, setSubject] = useState('');
  const [availableSubjects, setAvailableSubjects] = useState([]);
  const [isAddingSubject, setIsAddingSubject] = useState(false);
  const [newSubjectName, setNewSubjectName] = useState('');
  const [syllabusTopic, setSyllabusTopic] = useState('');
  const [activeListTab, setActiveListTab] = useState('history');
  
  const [isSidebarOpen, setIsSidebarOpen] = useState(true);
  const [viewMode, setViewMode] = useState('digest');
  const [searchQuery, setSearchQuery] = useState('');
  const [isAddingTag, setIsAddingTag] = useState(false);
  const [newTagValue, setNewTagValue] = useState('');
  
  // Window Control States
  const [isMaximized, setIsMaximized] = useState(false);
  const [isMinimized, setIsMinimized] = useState(false);
  const [collapsedSections, setCollapsedSections] = useState({});

  // Collective Digest States
  const [selectedCaseIds, setSelectedCaseIds] = useState([]);
  const [isCollectiveMode, setIsCollectiveMode] = useState(false);
  const collectiveRef = useRef(null);

  // Chat States
  const [isChatOpen, setIsChatOpen] = useState(false);
  const [chatMessages, setChatMessages] = useState([]);
  const [chatInput, setChatInput] = useState('');
  const [isChatLoading, setIsChatLoading] = useState(false);
  const chatMessagesEndRef = useRef(null);

  // Gemini API Feature States
  const [isDraftingRecit, setIsDraftingRecit] = useState(false);

  // Highlighter States
  const [highlighterPos, setHighlighterPos] = useState(null);
  const contentAreaRef = useRef(null);

  useEffect(() => {
    const subjectsFromHistory = Array.from(new Set(history.map(h => h.subject).filter(Boolean)));
    if (subjectsFromHistory.length > 0) {
      setAvailableSubjects(prev => Array.from(new Set([...prev, ...subjectsFromHistory])));
    }
  }, [history]);

  useEffect(() => {
    const style = document.createElement('style');
    style.innerHTML = `
      @import url('https://fonts.googleapis.com/css2?family=Open+Sans:ital,wght@0,400;0,600;0,700;1,400&display=swap');
      @font-face { font-family: 'Google Sans'; src: local('Open Sans'), local('Arial'); }
      .digest-content, .digest-table th, .digest-table td, .source-content {
        font-family: 'Google Sans', 'Open Sans', sans-serif !important;
        font-size: 8pt !important;
        text-align: justify !important;
        line-height: 1.5 !important;
      }
      .smart-text strong { color: #111827; font-weight: 700; }
      .dark .smart-text strong { color: #f9fafb; }
      .custom-scrollbar::-webkit-scrollbar { width: 6px; height: 6px; }
      .custom-scrollbar::-webkit-scrollbar-track { background: transparent; }
      .custom-scrollbar::-webkit-scrollbar-thumb { background-color: #cbd5e1; border-radius: 4px; }
      .dark .custom-scrollbar::-webkit-scrollbar-thumb { background-color: #475569; }
      
      /* Custom Highlight Colors */
      mark.hl-yellow { background-color: #fef08a; color: inherit; padding: 0 2px; border-radius: 2px;}
      mark.hl-green { background-color: #bbf7d0; color: inherit; padding: 0 2px; border-radius: 2px;}
      mark.hl-blue { background-color: #bfdbfe; color: inherit; padding: 0 2px; border-radius: 2px;}
      mark.hl-pink { background-color: #fbcfe8; color: inherit; padding: 0 2px; border-radius: 2px;}
      .dark mark.hl-yellow { background-color: #854d0e; color: white;}
      .dark mark.hl-green { background-color: #166534; color: white;}
      .dark mark.hl-blue { background-color: #1e40af; color: white;}
      .dark mark.hl-pink { background-color: #9d174d; color: white;}
      
      /* ContentEditable Editor Adjustments */
      .collective-editor:focus { outline: none; }
      .collective-editor table { cursor: text; }
    `;
    document.head.appendChild(style);
    return () => document.head.removeChild(style);
  }, []);

  useEffect(() => {
    if (chatMessagesEndRef.current) chatMessagesEndRef.current.scrollIntoView({ behavior: 'smooth' });
  }, [chatMessages, isChatOpen]);

  useEffect(() => {
    if (currentDigest) {
      setChatMessages([{ role: 'model', text: `Good day, Counsel. We are reviewing **${currentDigest.title}**. Ask me a direct question, or give me a situational problem and I will answer using the ALAC method.` }]);
    } else if (chatMessages.length === 0) {
      setChatMessages([{ role: 'model', text: `Good day, Counsel. I am Dean Sabio. Digest a case first so we can discuss it, or ask me any general questions regarding Philippine law.` }]);
    }
  }, [currentDigest]);

  const toggleSection = (sectionName) => {
    setCollapsedSections(prev => ({ ...prev, [sectionName]: !prev[sectionName] }));
  };

  const handleAddSubject = () => {
    if (!newSubjectName.trim()) return;
    const sub = newSubjectName.trim();
    if (!availableSubjects.includes(sub)) setAvailableSubjects([...availableSubjects, sub]);
    setSubject(sub);
    setNewSubjectName('');
    setIsAddingSubject(false);
  };

  const handleTextSelection = () => {
    if (isCollectiveMode) return; 
    const selection = window.getSelection();
    if (selection && selection.toString().trim().length > 0 && contentAreaRef.current) {
      const range = selection.getRangeAt(0);
      const rect = range.getBoundingClientRect();
      const containerRect = contentAreaRef.current.getBoundingClientRect();
      
      setHighlighterPos({
        top: rect.top - containerRect.top + contentAreaRef.current.scrollTop - 45,
        left: rect.left - containerRect.left + contentAreaRef.current.scrollLeft + (rect.width / 2) - 80
      });
    } else {
      setHighlighterPos(null);
    }
  };

  const applyHighlight = (colorClass, e) => {
    e.preventDefault();
    const selection = window.getSelection();
    if (!selection.rangeCount) return;
    const range = selection.getRangeAt(0);
    const mark = document.createElement('mark');
    mark.className = colorClass;
    try { range.surroundContents(mark); } catch (err) { console.warn("Highlighting partial range."); }
    selection.removeAllRanges();
    setHighlighterPos(null);
  };

  const removeHighlight = (e) => {
    e.preventDefault();
    const selection = window.getSelection();
    if (!selection.rangeCount) return;
    
    const range = selection.getRangeAt(0);
    const container = range.commonAncestorContainer.nodeType === 1 ? range.commonAncestorContainer : range.commonAncestorContainer.parentNode;
    
    if (container.tagName === 'MARK') {
      const parent = container.parentNode;
      while (container.firstChild) parent.insertBefore(container.firstChild, container);
      parent.removeChild(container);
    } else {
      const marks = container.querySelectorAll('mark');
      marks.forEach(mark => {
        if (selection.containsNode(mark, true)) {
          const parent = mark.parentNode;
          while (mark.firstChild) parent.insertBefore(mark.firstChild, mark);
          parent.removeChild(mark);
        }
      });
    }
    
    selection.removeAllRanges();
    setHighlighterPos(null);
  };

  const handleUpdateNotes = (text) => {
    const updatedDigest = { ...currentDigest, personal_notes: text };
    setCurrentDigest(updatedDigest);
    setHistory(prev => prev.map(item => item.id === currentDigest.id ? updatedDigest : item));
  };

  const handleDeleteDigest = (id, e) => {
    e.stopPropagation();
    setHistory(prev => prev.filter(item => item.id !== id));
    setSelectedCaseIds(prev => prev.filter(selectedId => selectedId !== id));
    if (currentDigest && currentDigest.id === id) closeDigest();
  };

  const handleDeleteSubject = (subjectName, e) => {
    e.stopPropagation();
    setHistory(prev => prev.map(item => item.subject === subjectName ? { ...item, subject: 'Uncategorized' } : item));
    setAvailableSubjects(prev => prev.filter(sub => sub !== subjectName));
    if (subject === subjectName) setSubject('');
  };

  const startNewDigest = () => {
    setCurrentDigest(null);
    setIsCollectiveMode(false);
    setInputValue('');
    setHighlighterPos(null);
    setIsSidebarOpen(true);
    setActiveSidebarTab('new');
    setViewMode('digest');
    setIsMaximized(false);
    setIsMinimized(false);
  };

  const closeDigest = () => {
    setCurrentDigest(null);
    setIsMaximized(false);
    setIsMinimized(false);
    setHighlighterPos(null);
  };

  const openCollectiveView = () => {
    setIsCollectiveMode(true);
    setCurrentDigest(null);
    setIsSidebarOpen(false); 
    setIsMaximized(false);
    setIsMinimized(false);
  };

  const closeCollectiveView = () => {
    setIsCollectiveMode(false);
    setIsMaximized(false);
    setIsMinimized(false);
    setSelectedCaseIds([]);
  };

  const toggleMinimize = () => {
    setIsMinimized(!isMinimized);
    if (!isMinimized) setIsMaximized(false);
  };

  const openDigestFromHistory = (item) => {
    setIsCollectiveMode(false);
    setCurrentDigest(item);
    setIsMinimized(false);
    setIsMaximized(false);
    setIsSidebarOpen(false); 
  };

  const toggleSelectCase = (id) => {
    setSelectedCaseIds(prev => 
      prev.includes(id) ? prev.filter(item => item !== id) : [...prev, id]
    );
  };

  const handleDraftRecitScript = async () => {
    if (!currentDigest || isDraftingRecit) return;
    setIsDraftingRecit(true);
    try {
      const prompt = `You are a brilliant Philippine law student. Draft a clear, confident, 2-minute law school recitation script for the case of "${currentDigest.title}". \n\nFacts: ${currentDigest.facts}\nIssues: ${currentDigest.issues.join(', ')}\nRatio: ${JSON.stringify(currentDigest.ratio_per_issue)}\n\nIMPORTANT: Include a short, clever mnemonic device to help remember the core doctrine at the end of the script. Format the script beautifully so it's easy to read aloud in class. Do not use HTML, just standard text with newlines.`;

      const payload = {
        contents: [{ parts: [{ text: prompt }] }],
        systemInstruction: { parts: [{ text: "You are an expert law student writing a script for a tough professor." }] }
      };

      const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-09-2025:generateContent?key=${apiKey}`;
      const response = await fetchWithRetry(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });

      const replyText = response.candidates?.[0]?.content?.parts?.[0]?.text;
      if (replyText) {
        const existingNotes = currentDigest.personal_notes || "";
        const newNotes = existingNotes ? `${existingNotes}\n\n==========\n✨ RECITATION SCRIPT ✨\n==========\n${replyText}` : `✨ RECITATION SCRIPT ✨\n==========\n${replyText}`;
        handleUpdateNotes(newNotes);
      }
    } catch (err) {
      console.error("Failed to draft recit:", err);
      alert("Failed to connect to the Gemini API to draft the script.");
    } finally {
      setIsDraftingRecit(false);
    }
  };

  const handleDigest = async () => {
    if (!inputValue.trim()) {
      setError('Please provide a case URL or text to digest.');
      return;
    }

    if (inputType === 'url') {
      try {
        new URL(inputValue);
      } catch (_) {
        setError('Invalid URL format. Please enter a complete link (e.g., https://lawphil.net/...).');
        return;
      }
    }

    setIsProcessing(true);
    setError(null);
    setCurrentDigest(null);
    setIsCollectiveMode(false);
    setViewMode('digest');
    setIsMaximized(false);
    setIsMinimized(false);
    setCollapsedSections({});

    try {
      let sourceTextToProcess = inputValue;
      let fetchSuccess = inputType === 'text'; 

      // NEW: Aggressive multi-proxy scraping specifically targeting jur.ph and lawphil. 
      // If they all fail, we set fetchSuccess = false and fallback to AI Search.
      if (inputType === 'url') {
        let htmlContent = "";
        const proxies = [
          `https://api.allorigins.win/get?url=${encodeURIComponent(inputValue)}`, // Returns JSON, bypasses many blocks
          `https://api.codetabs.com/v1/proxy/?quest=${encodeURIComponent(inputValue)}`, // Raw HTML
          `https://corsproxy.io/?url=${encodeURIComponent(inputValue)}`
        ];

        for (let i = 0; i < proxies.length; i++) {
          try {
            const res = await fetch(proxies[i]);
            if (res.ok) {
              let text = "";
              if (proxies[i].includes('allorigins.win/get')) {
                 const data = await res.json();
                 text = data.contents;
              } else {
                 text = await res.text();
              }
              
              if (text && text.length > 500 && !text.includes("Just a moment...") && !text.includes("Enable JavaScript")) {
                htmlContent = text;
                break; // Success
              }
            }
          } catch (e) {
            console.warn(`Proxy ${i + 1} failed.`);
          }
        }

        if (htmlContent) {
          const doc = new DOMParser().parseFromString(htmlContent, 'text/html');
          doc.querySelectorAll('script, style, nav, header, footer, iframe, img, aside, button, input').forEach(el => el.remove());
          
          let cleanHtml = doc.body.innerHTML
            .replace(/<br\s*\/?>/gi, '\n')
            .replace(/<\/p>/gi, '\n\n')
            .replace(/<\/div>/gi, '\n')
            .replace(/<\/li>/gi, '\n')
            .replace(/<\/h[1-6]>/gi, '\n\n');
            
          const tempDiv = document.createElement('div');
          tempDiv.innerHTML = cleanHtml;
          sourceTextToProcess = tempDiv.textContent.replace(/\n\s*\n/g, '\n\n').trim();

          if (sourceTextToProcess.length >= 300) {
             fetchSuccess = true;
          }
        }
      }

      const topicInstruction = syllabusTopic.trim() ? `\n\nCRUCIAL INSTRUCTION: The user is studying this case under the specific syllabus topic: "${syllabusTopic.trim()}". You MUST identify the issue related to this topic. Format it with a number AND completely wrap the ENTIRE sentence in Markdown bold (e.g., "1. **Whether or not...**"). Focus your deepest analysis on this issue.` : "";
      
      const notebookLmPrompt = `You are an elite legal scholar. I need an EXHAUSTIVELY COMPREHENSIVE case digest. Dive deep into the nuances of the facts and procedural history. \nVERY IMPORTANT FOR RATIO: Under 'ratio_per_issue', provide a massive, detailed, essay-length explanation for EACH issue. Detail the exact application of the law to the facts issue by issue.`;

      let promptText = "";
      if (inputType === 'url' && !fetchSuccess) {
        promptText = `${notebookLmPrompt}\n\nI am providing the URL: ${inputValue}. The direct scraper was blocked by website security. YOU MUST use your Google Search tool to search for this specific case (extract the GR number or title from the URL string). Read the full text online. \nCRITICAL: You must digest the EXACT case from the URL. Do not confuse it with cases having similar names. \nIn the 'extracted_source_text' field, provide a DETAILED NARRATIVE RECONSTRUCTION of the full case text. ${topicInstruction}`;
      } else {
        promptText = `${notebookLmPrompt}\n\nCase Text:\n${sourceTextToProcess.substring(0, 90000)}\n\n${topicInstruction}`;
      }

      const payload = {
        contents: [{ parts: [{ text: promptText }] }],
        systemInstruction: {
          parts: [{ text: "You are an expert legal assistant. Make the digest extremely comprehensive. Use Markdown double asterisks (**text**) to bold key terms. Format output STRICTLY as a JSON object." }]
        },
        tools: [{ google_search: {} }], // Always include tools in case it needs to fallback
        generationConfig: {
          responseMimeType: "application/json",
          responseSchema: {
            type: "OBJECT",
            properties: {
              short_title: { type: "STRING" },
              title: { type: "STRING" },
              gr_no: { type: "STRING" },
              date: { type: "STRING" },
              petitioner: { type: "STRING" },
              respondent: { type: "STRING" },
              brief_summary: { type: "STRING" },
              tags: { type: "ARRAY", items: { type: "STRING" } },
              extracted_source_text: { type: "STRING" },
              facts: { type: "STRING" },
              ruling_lower_courts: {
                type: "ARRAY",
                items: {
                  type: "OBJECT",
                  properties: { court: { type: "STRING" }, ruling: { type: "STRING" } },
                  required: ["court", "ruling"]
                }
              },
              issues: { type: "ARRAY", items: { type: "STRING" } },
              ruling_per_issue: { 
                type: "ARRAY", 
                items: { 
                  type: "OBJECT",
                  properties: { issue_reference: { type: "STRING" }, ruling: { type: "STRING" } },
                  required: ["issue_reference", "ruling"]
                }
              },
              ratio_per_issue: { 
                type: "ARRAY", 
                items: { 
                  type: "OBJECT",
                  properties: { issue_reference: { type: "STRING" }, ratio: { type: "STRING" } },
                  required: ["issue_reference", "ratio"]
                }
              },
              dispositive_portion: { type: "STRING" },
              doctrines: { type: "ARRAY", items: { type: "STRING" } },
              case_notes: { type: "ARRAY", items: { type: "STRING" } }
            },
            required: ["title", "gr_no", "date", "petitioner", "respondent", "brief_summary", "tags", "facts", "ruling_lower_courts", "issues", "ruling_per_issue", "ratio_per_issue", "dispositive_portion", "doctrines", "case_notes"]
          }
        }
      };

      const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-09-2025:generateContent?key=${apiKey}`;
      const response = await fetchWithRetry(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });

      const jsonText = response.candidates?.[0]?.content?.parts?.[0]?.text;
      
      if (!jsonText) throw new Error("The AI failed to generate a response. Try pasting smaller chunks directly.");

      const digestData = JSON.parse(jsonText);
      const newDigest = { 
        ...digestData, 
        id: Date.now(), 
        addedAt: new Date().toLocaleString('en-US', { month: 'short', day: 'numeric', year: 'numeric', hour: '2-digit', minute: '2-digit' }),
        input: inputValue,
        inputType: inputType,
        extracted_source_text: inputType === 'text' ? inputValue : (fetchSuccess ? sourceTextToProcess : (digestData.extracted_source_text || "Failed to extract source text. AI used Google Search to infer facts.")),
        subject: subject || 'Uncategorized',
        personal_notes: ''
      };
      
      setCurrentDigest(newDigest);
      setHistory([newDigest, ...history]);
      
      if (window.innerWidth < 1024) setIsSidebarOpen(false);

    } catch (err) {
      console.error(err);
      setError(err.message || 'An error occurred while digesting the case.');
    } finally {
      setIsProcessing(false);
    }
  };

  const handleChatSend = async (overrideText = null) => {
    const textToSend = overrideText || chatInput;
    if (!textToSend.trim() || isChatLoading) return;
    
    const userMsg = { role: 'user', text: textToSend };
    setChatMessages(prev => [...prev, userMsg]);
    if (!overrideText) setChatInput('');
    setIsChatLoading(true);

    try {
      const apiHistory = chatMessages.map(msg => ({
        role: msg.role === 'model' ? 'model' : 'user',
        parts: [{ text: msg.text }]
      }));
      apiHistory.push({ role: 'user', parts: [{ text: userMsg.text }] });

      const contextText = currentDigest ? `Context: ${currentDigest.title}\nFacts: ${currentDigest.facts}\nRatio: ${JSON.stringify(currentDigest.ratio_per_issue)}` : "No case selected. Provide general law guidance.";

      const payload = {
        contents: apiHistory,
        systemInstruction: {
          parts: [{ text: `You are 'Dean Sabio'. 1. If a law related question or inquiry is direct, answer it directly. 2. But if the question is situational, answer it like a law student, or using the ALAC method. Stay authoritative. Context:\n${contextText}` }]
        }
      };

      const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-09-2025:generateContent?key=${apiKey}`;
      const response = await fetchWithRetry(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });

      const replyText = response.candidates?.[0]?.content?.parts?.[0]?.text;
      if (replyText) setChatMessages(prev => [...prev, { role: 'model', text: replyText }]);
    } catch (err) {
      setChatMessages(prev => [...prev, { role: 'model', text: "Counselor, I'm having trouble retrieving my notes right now." }]);
    } finally {
      setIsChatLoading(false);
    }
  };

  const executeRichTextCopy = (htmlToCopy, fallbackTitle) => {
    try {
      const blobHtml = new Blob([htmlToCopy], { type: 'text/html' });
      const clipboardItem = new window.ClipboardItem({ 'text/html': blobHtml, 'text/plain': new Blob([fallbackTitle], { type: 'text/plain' }) });
      navigator.clipboard.write([clipboardItem]).then(() => {
        setCopiedSection('docs'); setTimeout(() => setCopiedSection(null), 2000);
      });
    } catch (err) {
      const el = document.createElement('div'); el.innerHTML = htmlToCopy;
      el.style.position = 'absolute'; el.style.left = '-9999px'; document.body.appendChild(el);
      const range = document.createRange(); range.selectNodeContents(el);
      window.getSelection().removeAllRanges(); window.getSelection().addRange(range);
      document.execCommand('copy'); setCopiedSection('docs');
      setTimeout(() => setCopiedSection(null), 2000); document.body.removeChild(el);
    }
  };

  const copyRichTextToDocs = () => {
    if (!currentDigest) return;
    const htmlToCopy = `<div style="font-family: 'Google Sans', sans-serif; font-size: 8pt; color: #000000;">${generateCaseTableHtml(currentDigest)}</div>`;
    executeRichTextCopy(htmlToCopy, currentDigest.title);
  };

  const copyCollectiveToDocs = () => {
    if (!collectiveRef.current) return;
    const htmlToCopy = `<div style="font-family: 'Google Sans', sans-serif; font-size: 8pt; color: #000000;">${collectiveRef.current.innerHTML}</div>`;
    executeRichTextCopy(htmlToCopy, 'Collective Digest');
  };

  const handlePrint = (isCollective) => {
    let html = '';
    let title = '';
    if (isCollective && collectiveRef.current) {
      html = `<div style="font-family: 'Google Sans', sans-serif; font-size: 8pt; color: #000000;">${collectiveRef.current.innerHTML}</div>`;
      title = 'Collective Digest';
    } else if (currentDigest) {
      html = `<div style="font-family: 'Google Sans', sans-serif; font-size: 8pt; color: #000000;">${generateCaseTableHtml(currentDigest)}</div>`;
      title = currentDigest.title;
    }
    if (!html) return;
    
    const printWindow = window.open('', '_blank');
    printWindow.document.write(`
      <html>
        <head>
          <title>${title}</title>
          <style>
            body { font-family: 'Open Sans', Arial, sans-serif; color: black; background: white; padding: 20px; }
            table { width: 100%; border-collapse: collapse; margin-bottom: 40px; font-size: 10pt; line-height: 1.5; }
            th, td { border: 1px solid black; padding: 10px; text-align: left; vertical-align: top; }
            th { background-color: #f3f4f6; width: 20%; font-weight: bold; }
            td { width: 80%; text-align: justify; }
            ol, ul { margin-top: 0; padding-left: 20px; }
            p { margin-top: 0; margin-bottom: 8px; }
            @media print {
              table { page-break-inside: auto; }
              tr { page-break-inside: avoid; page-break-after: auto; }
              br { page-break-after: always; clear: both; }
            }
          </style>
        </head>
        <body>
          ${html}
          <script>
            window.onload = () => { window.print(); window.close(); };
          </script>
        </body>
      </html>
    `);
    printWindow.document.close();
  };

  const copySectionPlain = (text, sectionId) => {
    if (!text) return;
    try {
      const textArea = document.createElement("textarea");
      textArea.value = text.replace(/\*\*(.*?)\*\*/g, '$1'); 
      document.body.appendChild(textArea);
      textArea.select();
      document.execCommand("copy");
      document.body.removeChild(textArea);
      setCopiedSection(sectionId);
      setTimeout(() => setCopiedSection(null), 2000);
    } catch (err) { console.error(err); }
  };

  const handleAddTag = () => {
    if (!newTagValue.trim() || !currentDigest) return;
    const updatedTags = [...(currentDigest.tags || []), newTagValue.trim()];
    const updatedDigest = { ...currentDigest, tags: updatedTags };
    setCurrentDigest(updatedDigest);
    setHistory(prev => prev.map(item => item.id === currentDigest.id ? updatedDigest : item));
    setNewTagValue(''); setIsAddingTag(false);
  };

  const handleRemoveTag = (tag) => {
    const updatedTags = currentDigest.tags.filter(t => t !== tag);
    const updatedDigest = { ...currentDigest, tags: updatedTags };
    setCurrentDigest(updatedDigest);
    setHistory(prev => prev.map(item => item.id === currentDigest.id ? updatedDigest : item));
  };

  const filteredHistory = history.filter(item => {
    const q = searchQuery.toLowerCase();
    return (item.title?.toLowerCase().includes(q) || item.gr_no?.toLowerCase().includes(q) || item.tags?.some(t => t.toLowerCase().includes(q)) || item.subject?.toLowerCase().includes(q));
  });

  const renderHistoryItem = (item, isDashboard = false) => (
    <div key={item.id} className={`border transition-colors group flex ${currentDigest?.id === item.id ? 'bg-blue-50 border-blue-500 dark:bg-blue-900/20' : 'bg-white dark:bg-slate-800 border-slate-200 dark:border-slate-700 hover:border-slate-400'} ${isDashboard ? 'shadow-sm' : ''}`}>
      <div className={`pt-4 pl-4 ${isDashboard ? 'pt-5 pl-5' : ''}`}>
        <input 
          type="checkbox" 
          className="w-4 h-4 text-blue-600 rounded border-slate-300 focus:ring-blue-500 cursor-pointer"
          checked={selectedCaseIds.includes(item.id)}
          onChange={(e) => {
            e.stopPropagation();
            toggleSelectCase(item.id);
          }}
          onClick={e => e.stopPropagation()}
        />
      </div>
      <div className={`flex-grow cursor-pointer ${isDashboard ? 'p-5 pl-3' : 'p-4 pl-3'}`} onClick={() => openDigestFromHistory(item)}>
        <div className="flex justify-between items-start">
          <h3 className={`font-bold line-clamp-1 pr-2 ${isDashboard ? 'text-sm' : 'text-xs'}`}>{item.short_title || item.title}</h3>
          <button onClick={(e) => handleDeleteDigest(item.id, e)} className="text-slate-400 hover:text-red-500 opacity-0 group-hover:opacity-100 transition-opacity">
            <Trash2 className="w-3.5 h-3.5" />
          </button>
        </div>
        <div className={`text-slate-400 mt-1 font-mono uppercase tracking-wider ${isDashboard ? 'text-[10px]' : 'text-[9px]'}`}>{item.addedAt}</div>
        <div className="max-h-0 opacity-0 overflow-hidden group-hover:max-h-64 group-hover:opacity-100 transition-all duration-300 ease-in-out">
          <div className={`text-slate-500 italic leading-relaxed border-t border-slate-100 dark:border-slate-700 pt-2 mt-2 ${isDashboard ? 'text-xs' : 'text-[10px]'}`}>
            {item.brief_summary}
          </div>
        </div>
      </div>
    </div>
  );

  const renderNewDigestForm = (isDashboard = false) => (
    <div className={`flex flex-col h-full bg-white dark:bg-slate-900 border border-slate-300 dark:border-slate-800 ${isDashboard ? 'p-8 shadow-xl rounded-sm' : 'p-6 border-b-0'}`}>
      <h2 className={`uppercase font-bold mb-6 flex items-center text-blue-600 tracking-widest ${isDashboard ? 'text-lg' : 'text-[10px]'}`}>
        <BookOpen className={`${isDashboard ? 'w-6 h-6 mr-3' : 'w-4 h-4 mr-2'}`} />
        New Digest
      </h2>
      
      <div className="mb-4">
        <div className="flex justify-between items-center mb-1.5">
          <label className={`block font-bold text-slate-700 dark:text-slate-300 uppercase tracking-wider ${isDashboard ? 'text-xs' : 'text-[10px]'}`}>Subject</label>
          {!isAddingSubject && <button onClick={() => setIsAddingSubject(true)} className={`font-bold text-blue-600 uppercase hover:underline ${isDashboard ? 'text-xs' : 'text-[9px]'}`}>+ New Subject</button>}
        </div>
        {isAddingSubject ? (
          <div className="flex items-center gap-1">
            <input type="text" placeholder="Enter subject..." value={newSubjectName} onChange={e => setNewSubjectName(e.target.value)} onKeyDown={e => e.key === 'Enter' && handleAddSubject()} className={`w-full border focus:outline-none focus:border-blue-500 dark:bg-slate-800 dark:border-slate-700 ${isDashboard ? 'px-4 py-3 text-sm' : 'px-2 py-1.5 text-xs'}`} autoFocus />
            <button onClick={handleAddSubject} className={`bg-blue-600 text-white hover:bg-blue-700 ${isDashboard ? 'p-3' : 'p-1.5'}`}><Check className={isDashboard ? "w-5 h-5" : "w-3.5 h-3.5"} /></button>
            <button onClick={() => setIsAddingSubject(false)} className={`bg-slate-200 text-slate-600 hover:bg-slate-300 ${isDashboard ? 'p-3' : 'p-1.5'}`}><X className={isDashboard ? "w-5 h-5" : "w-3.5 h-3.5"} /></button>
          </div>
        ) : (
          <select value={subject} onChange={e => setSubject(e.target.value)} className={`w-full border focus:outline-none dark:bg-slate-800 dark:border-slate-700 appearance-none bg-slate-50 dark:bg-slate-900 ${isDashboard ? 'px-4 py-3 text-sm' : 'px-3 py-2 text-xs'}`}>
            <option value="" disabled>Select a subject...</option>
            {availableSubjects.map(sub => <option key={sub} value={sub}>{sub}</option>)}
          </select>
        )}
      </div>

      <div className="mb-5">
        <label className={`block font-bold text-slate-700 dark:text-slate-300 mb-1.5 uppercase tracking-wider ${isDashboard ? 'text-xs' : 'text-[10px]'}`}>Focus Topic (Optional)</label>
        <input type="text" placeholder="e.g. Self-Defense" value={syllabusTopic} onChange={e => setSyllabusTopic(e.target.value)} className={`w-full border focus:outline-none dark:bg-slate-800 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 ${isDashboard ? 'px-4 py-3 text-sm' : 'px-3 py-2 text-xs'}`} />
      </div>

      <div className="flex border border-slate-300 dark:border-slate-700 mb-4 bg-slate-100 dark:bg-slate-800 p-0.5">
        <button onClick={() => { setInputType('url'); setInputValue(''); setError(null); }} className={`flex-1 font-bold uppercase tracking-wider transition-colors ${inputType === 'url' ? 'bg-white dark:bg-slate-900 text-blue-600 shadow-sm border border-slate-200 dark:border-slate-700' : 'text-slate-500'} ${isDashboard ? 'py-3 text-xs' : 'py-2 text-[10px]'}`}>Link</button>
        <button onClick={() => { setInputType('text'); setInputValue(''); setError(null); }} className={`flex-1 font-bold uppercase tracking-wider transition-colors ${inputType === 'text' ? 'bg-white dark:bg-slate-900 text-blue-600 shadow-sm border border-slate-200 dark:border-slate-700' : 'text-slate-500'} ${isDashboard ? 'py-3 text-xs' : 'py-2 text-[10px]'}`}>Raw Text</button>
      </div>
      
      <textarea placeholder={inputType === 'url' ? "Paste case URL (e.g. https://lawphil.net/... or https://jur.ph/...)" : "Paste full case text here..."} value={inputValue} onChange={e => setInputValue(e.target.value)} rows={inputType === 'url' ? 2 : 10} className={`w-full border border-slate-300 dark:border-slate-700 focus:outline-none dark:bg-slate-800 resize-none flex-grow mb-5 bg-slate-50 dark:bg-slate-900 custom-scrollbar ${isDashboard ? 'px-5 py-4 text-sm' : 'px-4 py-3 text-xs'}`} />
      
      {error && (
        <div className="mb-4 p-3 bg-red-50 border border-red-200 flex items-start text-red-600 text-xs leading-tight">
          <AlertCircle className="w-4 h-4 mr-2 flex-shrink-0 mt-0.5" />
          <span>{error}</span>
        </div>
      )}

      <button onClick={handleDigest} disabled={isProcessing} className={`w-full bg-blue-600 text-white font-bold uppercase hover:bg-blue-700 transition-colors flex items-center justify-center tracking-widest shadow-md ${isDashboard ? 'py-5 text-sm' : 'py-4 text-[11px]'}`}>
        {isProcessing ? <><Loader2 className="animate-spin h-5 w-5 mr-3" />PROCESSING</> : "GENERATE DIGEST"}
      </button>
    </div>
  );

  const renderLibraryPanel = (isDashboard = false) => (
    <div className={`flex-grow flex flex-col min-h-0 bg-slate-50 dark:bg-slate-900/50 ${isDashboard ? 'bg-white dark:bg-slate-900 border border-slate-300 dark:border-slate-800 shadow-xl rounded-sm' : ''}`}>
      
      <div className="bg-slate-100 dark:bg-slate-800 py-3 px-4 border-b border-slate-200 dark:border-slate-700 flex justify-between items-center flex-shrink-0">
         <span className="text-[10px] font-bold text-slate-500 uppercase tracking-widest flex items-center">
            <Layers className="w-4 h-4 mr-2 text-blue-500" /> Collective Digest Mode
         </span>
         {selectedCaseIds.length > 0 && (
            <button onClick={openCollectiveView} className="bg-blue-600 text-white text-[9px] px-4 py-2 rounded-sm font-bold uppercase tracking-widest hover:bg-blue-700 shadow-sm transition-transform active:scale-95 flex items-center pointer-events-auto">
               COMPILE ({selectedCaseIds.length}) <ChevronRight className="w-3 h-3 ml-1" />
            </button>
         )}
      </div>

      <div className={`flex border-b border-slate-200 dark:border-slate-800 flex-shrink-0 ${isDashboard ? 'bg-slate-100 dark:bg-slate-900' : 'bg-white dark:bg-slate-900'}`}>
        <button onClick={() => setActiveListTab('history')} className={`flex-1 font-bold uppercase tracking-widest transition-colors ${activeListTab === 'history' ? 'bg-white dark:bg-slate-800 text-blue-600 border-b-2 border-blue-600' : 'text-slate-500 hover:bg-slate-50 dark:hover:bg-slate-800'} ${isDashboard ? 'py-4 text-xs' : 'py-3 text-[9px]'}`}>History</button>
        <button onClick={() => setActiveListTab('subjects')} className={`flex-1 font-bold uppercase tracking-widest transition-colors ${activeListTab === 'subjects' ? 'bg-white dark:bg-slate-800 text-blue-600 border-b-2 border-blue-600' : 'text-slate-500 hover:bg-slate-50 dark:hover:bg-slate-800'} ${isDashboard ? 'py-4 text-xs' : 'py-3 text-[9px]'}`}>Subjects</button>
      </div>

      <div className={`p-4 border-b border-slate-200 dark:border-slate-800 relative flex-shrink-0 ${isDashboard ? 'bg-white dark:bg-slate-900' : 'bg-slate-50 dark:bg-slate-900'}`}>
        <input type="text" placeholder="Search saved cases..." value={searchQuery} onChange={e => setSearchQuery(e.target.value)} className={`w-full pl-10 pr-4 border focus:outline-none dark:bg-slate-800 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 ${isDashboard ? 'py-3 text-sm' : 'py-2.5 text-[11px]'}`} />
        <Search className={`absolute text-slate-400 ${isDashboard ? 'w-5 h-5 left-7 top-4' : 'w-4 h-4 left-7 top-5'}`} />
      </div>
      
      <div className={`flex-grow overflow-y-auto custom-scrollbar space-y-3 ${isDashboard ? 'p-6' : 'p-4'}`}>
        {activeListTab === 'history' ? filteredHistory.map(item => renderHistoryItem(item, isDashboard)) 
        : Array.from(new Set(filteredHistory.map(h => h.subject).filter(Boolean))).map(subjectName => (
          <div key={subjectName} className="mb-6">
            <div className="flex justify-between items-center mb-3 group/subject">
              <h3 className={`font-bold text-slate-500 uppercase tracking-widest flex items-center ${isDashboard ? 'text-xs' : 'text-[10px]'}`}>
                <BookOpen className={`mr-2 text-blue-500 ${isDashboard ? 'w-4 h-4' : 'w-3.5 h-3.5'}`} />{subjectName}
              </h3>
              {subjectName !== 'Uncategorized' && (
                <button onClick={(e) => handleDeleteSubject(subjectName, e)} className="text-slate-400 hover:text-red-500 opacity-0 group-hover/subject:opacity-100 transition-opacity">
                  <Trash2 className="w-3.5 h-3.5" />
                </button>
              )}
            </div>
            <div className="space-y-2 pl-3 border-l-2 border-slate-200 dark:border-slate-800 ml-1.5">
              {filteredHistory.filter(h => h.subject === subjectName).map(item => renderHistoryItem(item, isDashboard))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );

  const collectiveCases = history.filter(item => selectedCaseIds.includes(item.id));
  const showDashboard = (!currentDigest && !isCollectiveMode);

  return (
    <div className="min-h-screen bg-slate-100 dark:bg-[#0f172a] text-slate-900 dark:text-slate-100 font-sans selection:bg-blue-200 dark:selection:bg-blue-900 flex flex-col relative overflow-hidden">
      
      {/* Welcome Popup */}
      {showWelcome && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center bg-slate-900/90 p-4 backdrop-blur-sm">
          <div className="bg-white dark:bg-slate-900 border border-slate-300 dark:border-slate-700 p-10 max-w-md w-full text-center animate-in shadow-2xl rounded-sm">
            <Scale className="w-14 h-14 text-blue-600 mx-auto mb-6" />
            <h1 className="text-3xl font-bold tracking-widest uppercase mb-2 text-slate-900 dark:text-white">HELLO ATTORNEY.</h1>
            <p className="text-slate-500 mb-10 text-sm uppercase tracking-wide">Welcome to PELEP Law Digestor</p>
            <button onClick={() => { setShowWelcome(false); setShowUpdates(true); }} className="w-full py-4 bg-blue-600 hover:bg-blue-700 text-white font-bold text-sm uppercase tracking-widest transition-colors shadow-md">ENTER DIGESTOR</button>
          </div>
        </div>
      )}

      {/* Updates Popup */}
      {showUpdates && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center bg-slate-900/90 p-4 backdrop-blur-sm">
          <div className="bg-white dark:bg-slate-900 border border-slate-300 dark:border-slate-700 p-8 max-w-md w-full animate-in shadow-2xl rounded-sm">
            <h2 className="text-xl font-bold tracking-widest uppercase mb-4 text-slate-900 dark:text-white border-b border-slate-200 dark:border-slate-700 pb-3">Latest Updates</h2>
            <ul className="space-y-4 mb-8 text-sm text-slate-600 dark:text-slate-300">
              <li className="flex items-start"><Check className="w-5 h-5 mr-3 text-green-500 flex-shrink-0" /> <span className="pt-0.5"><strong>✨ Collective Digest:</strong> Select multiple cases and compile them into a live-editable document!</span></li>
              <li className="flex items-start"><Check className="w-5 h-5 mr-3 text-green-500 flex-shrink-0" /> <span className="pt-0.5"><strong>✨ Print to PDF:</strong> Native PDF generation for both single and collective digests.</span></li>
              <li className="flex items-start"><Check className="w-5 h-5 mr-3 text-green-500 flex-shrink-0" /> <span className="pt-0.5"><strong>Smart URL Extractor:</strong> Strict scraper prevents AI hallucination.</span></li>
              <li className="flex items-start"><Check className="w-5 h-5 mr-3 text-green-500 flex-shrink-0" /> <span className="pt-0.5"><strong>Interactive Highlighter:</strong> 4-color highlighting across views.</span></li>
              <li className="flex items-start"><Check className="w-5 h-5 mr-3 text-green-500 flex-shrink-0" /> <span className="pt-0.5"><strong>Dean Sabio AI:</strong> Your ALAC-enabled chat companion.</span></li>
            </ul>
            <button onClick={() => setShowUpdates(false)} className="w-full py-4 bg-blue-600 hover:bg-blue-700 text-white font-bold text-sm uppercase tracking-widest transition-colors shadow-md">PROCEED TO DASHBOARD</button>
          </div>
        </div>
      )}

      {/* Global Header */}
      {!isMaximized && (
        <header className="bg-white dark:bg-slate-900 border-b border-slate-300 dark:border-slate-800 h-16 flex items-center justify-between px-6 z-[60] relative flex-shrink-0">
          <div className="flex items-center space-x-4">
            <div className="flex items-center">
               <Scale className="w-6 h-6 text-blue-600 mr-2"/>
               <h1 className="text-lg font-bold tracking-widest uppercase">PELEP LAW DIGESTOR</h1>
            </div>
          </div>
          {(!showDashboard) && (
             <button onClick={startNewDigest} className="flex items-center text-xs font-bold text-slate-500 hover:text-blue-600 uppercase tracking-widest transition-colors">
                <Home className="w-4 h-4 mr-1.5" /> Dashboard
             </button>
          )}
        </header>
      )}

      <main className="flex-grow flex flex-col lg:flex-row gap-0 overflow-hidden relative">
        
        {/* DASHBOARD VIEW */}
        {(showDashboard || isMinimized) && (
          <div className={`absolute inset-0 z-10 overflow-y-auto bg-slate-50 dark:bg-[#0f172a] p-6 sm:p-10 custom-scrollbar ${isMinimized ? 'pb-24' : ''}`}>
             <div className="max-w-7xl mx-auto flex flex-col lg:flex-row gap-10 h-full min-h-[600px]">
                <div className="w-full lg:w-5/12 flex flex-col">
                   {renderNewDigestForm(true)}
                </div>
                <div className="w-full lg:w-7/12 flex flex-col">
                   {renderLibraryPanel(true)}
                </div>
             </div>
          </div>
        )}

        {/* OVERLAPPING SIDEBAR */}
        {!showDashboard && !isMinimized && (
          <>
            {isSidebarOpen && (
               <div className="fixed inset-0 z-30 bg-slate-900/20 lg:hidden backdrop-blur-sm pointer-events-auto" onClick={() => setIsSidebarOpen(false)} />
            )}
            <div className={`absolute z-40 h-full transition-transform duration-300 flex flex-col border-r border-slate-300 dark:border-slate-800 bg-white dark:bg-slate-900 shadow-[20px_0_40px_rgba(0,0,0,0.1)] ${isSidebarOpen && !isMaximized ? 'w-[85%] sm:w-[380px] translate-x-0' : 'w-[85%] sm:w-[380px] -translate-x-full border-none shadow-none'} pointer-events-auto`}>
              <div className="w-full flex flex-col h-full">
                <div className="p-5 border-b border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-900/50 flex items-center justify-between">
                   <button onClick={startNewDigest} className="flex-grow py-3.5 bg-white dark:bg-slate-800 border border-blue-200 dark:border-slate-700 text-blue-600 dark:text-blue-400 font-bold text-[11px] uppercase tracking-widest shadow-sm hover:border-blue-400 transition-colors flex items-center justify-center">
                      <PlusCircle className="w-4 h-4 mr-2" /> NEW DIGEST
                   </button>
                   <button onClick={() => setIsSidebarOpen(false)} className="ml-3 p-2 hover:bg-slate-200 dark:hover:bg-slate-800 text-slate-500 rounded-sm transition-colors shadow-sm bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700" title="Close Sidebar">
                     <PanelLeftClose className="w-4 h-4" />
                   </button>
                </div>
                {renderLibraryPanel()}
              </div>
            </div>
          </>
        )}

        {/* COLLECTIVE DIGEST VIEW */}
        {isCollectiveMode && !isMinimized && (
          <div className={`transition-all duration-300 flex flex-col bg-slate-100 dark:bg-[#0f172a] shadow-[0_-10px_40px_rgba(0,0,0,0.15)] ${
            isMaximized ? 'fixed inset-0 z-[70]' : 'flex-grow w-full min-h-0 relative z-20 pl-0'
          }`}>
            <div className="flex flex-col h-full overflow-hidden bg-white dark:bg-slate-900 shadow-xl border-l border-slate-300 dark:border-slate-800">
              <div className="p-6 border-b border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 flex justify-between items-center z-30 relative shadow-sm pointer-events-auto">
                <div className="flex-1 pr-6 flex items-center">
                  {!isSidebarOpen && !isMaximized && (
                    <button onClick={() => setIsSidebarOpen(true)} className="p-2 mr-4 border border-slate-200 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors text-slate-600 dark:text-slate-300 rounded-sm flex-shrink-0 shadow-sm bg-white dark:bg-slate-800" title="Open Sidebar">
                      <PanelLeftOpen className="w-4 h-4" />
                    </button>
                  )}
                  <div>
                    <h2 className="text-xl sm:text-2xl font-bold font-serif leading-tight uppercase tracking-tight text-blue-900 dark:text-blue-100 flex items-center">
                      <Layers className="w-6 h-6 mr-3 text-blue-600" /> Collective Digest
                    </h2>
                    <p className="text-xs font-bold text-slate-500 uppercase mt-2">{selectedCaseIds.length} Cases Selected • Click anywhere below to edit before exporting</p>
                  </div>
                </div>
                <div className="flex items-center space-x-3 flex-shrink-0 z-50">
                  <button onClick={() => handlePrint(true)} className="px-4 py-2 bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 text-slate-700 dark:text-slate-300 font-bold text-[10px] uppercase tracking-widest shadow-sm hover:bg-slate-200 dark:hover:bg-slate-700 transition-colors flex items-center">
                    <Printer className="w-3.5 h-3.5 mr-1" /> PDF
                  </button>
                  <button onClick={copyCollectiveToDocs} className="px-5 py-2 bg-blue-600 text-white font-bold text-[10px] uppercase tracking-widest shadow-sm hover:bg-blue-700 transition-colors flex items-center">
                    {copiedSection === 'docs' ? <Check className="w-3.5 h-3.5 mr-1" /> : <FileDown className="w-3.5 h-3.5 mr-1" />}
                    {copiedSection === 'docs' ? 'COPIED' : 'COPY COLLECTION'}
                  </button>
                  <div className="flex items-center border-l border-slate-300 dark:border-slate-700 pl-3 ml-3 space-x-1">
                    <button onClick={toggleMinimize} className="p-1.5 hover:bg-slate-100 dark:hover:bg-slate-800 text-slate-500 rounded transition-colors" title="Minimize">
                       <Minus className="w-4 h-4" />
                    </button>
                    <button onClick={() => setIsMaximized(!isMaximized)} className="p-1.5 hover:bg-slate-100 dark:hover:bg-slate-800 text-slate-500 rounded transition-colors" title={isMaximized ? "Restore Window" : "Maximize"}>
                      {isMaximized ? <Minimize className="w-4 h-4" /> : <Maximize className="w-4 h-4" />}
                    </button>
                    <button onClick={closeCollectiveView} className="p-1.5 hover:bg-red-500 hover:text-white dark:hover:bg-red-900/30 text-slate-500 rounded transition-colors" title="Close">
                      <X className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              </div>

              <div className="flex-grow overflow-y-auto p-4 sm:p-10 custom-scrollbar bg-slate-100 dark:bg-slate-950">
                <div 
                  className="collective-editor mx-auto max-w-5xl bg-white p-12 shadow-md min-h-[800px]"
                  contentEditable={true}
                  suppressContentEditableWarning={true}
                  ref={collectiveRef}
                >
                  {collectiveCases.map(digest => (
                    <div key={digest.id} dangerouslySetInnerHTML={{ __html: generateCaseTableHtml(digest) }} />
                  ))}
                </div>
              </div>
            </div>
          </div>
        )}

        {/* SINGLE DIGEST VIEW */}
        {currentDigest && !isCollectiveMode && !isMinimized && (
          <div className={`transition-all duration-300 flex flex-col bg-slate-100 dark:bg-[#0f172a] shadow-[0_-10px_40px_rgba(0,0,0,0.15)] ${
            isMaximized ? 'fixed inset-0 z-[70]' : 'flex-grow w-full min-h-0 relative z-20 pl-0'
          }`}>
            <div className="flex flex-col h-full overflow-hidden bg-white dark:bg-slate-900 shadow-xl border-l border-slate-300 dark:border-slate-800">
              
              <div className="p-6 border-b border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 flex justify-between items-center z-30 relative shadow-sm pointer-events-auto">
                <div className="flex-1 pr-6 min-w-0 flex items-center">
                  {!isSidebarOpen && !isMaximized && (
                    <button onClick={() => setIsSidebarOpen(true)} className="p-2 mr-4 border border-slate-200 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors text-slate-600 dark:text-slate-300 rounded-sm flex-shrink-0 shadow-sm bg-white dark:bg-slate-800" title="Open Sidebar">
                      <PanelLeftOpen className="w-5 h-5" />
                    </button>
                  )}
                  <div className="min-w-0">
                    <h2 className="text-xl sm:text-2xl font-bold font-serif leading-tight uppercase tracking-tight text-slate-900 dark:text-white truncate">
                      {currentDigest.title}
                    </h2>
                    <div className="flex flex-col mt-3 gap-2">
                      <p className="text-[10px] font-mono text-slate-500 uppercase">
                        {currentDigest.gr_no} // {currentDigest.date} <span className="ml-3 pl-3 border-l border-slate-300 dark:border-slate-700">{currentDigest.addedAt}</span>
                      </p>
                      <div className="flex flex-wrap items-center gap-2 mt-1">
                        {currentDigest.tags?.map((tag, idx) => (
                          <span key={idx} className="flex items-center text-[9px] font-bold bg-slate-100 dark:bg-slate-800 px-2 py-0.5 border border-slate-200 dark:border-slate-700 rounded-sm uppercase group">
                            <Tag className="w-2.5 h-2.5 mr-1 text-slate-400" />{tag}
                            <button onClick={() => handleRemoveTag(tag)} className="ml-1 opacity-0 group-hover:opacity-100 text-red-500"><X className="w-2.5 h-2.5"/></button>
                          </span>
                        ))}
                        {isAddingTag ? (
                          <div className="flex items-center"><input type="text" value={newTagValue} onChange={e => setNewTagValue(e.target.value)} onKeyDown={e => e.key === 'Enter' && handleAddTag()} autoFocus className="text-[9px] px-1 py-0.5 border border-blue-500 outline-none w-20" /></div>
                        ) : (
                          <button onClick={() => setIsAddingTag(true)} className="text-[9px] font-bold text-blue-600 hover:underline uppercase flex items-center"><Plus className="w-3 h-3 mr-0.5"/> Tag</button>
                        )}
                      </div>
                    </div>
                  </div>
                </div>
                
                <div className="flex items-center flex-shrink-0 relative z-50 pointer-events-auto">
                  <div className="flex border border-slate-200 dark:border-slate-800 p-0.5 bg-slate-50 dark:bg-slate-800 rounded-sm mr-3">
                    <button onClick={() => setViewMode('digest')} className={`px-4 py-1.5 text-[10px] font-bold uppercase tracking-widest transition-colors ${viewMode === 'digest' ? 'bg-white dark:bg-slate-900 shadow-sm border border-slate-200 dark:border-slate-700 text-slate-900 dark:text-white' : 'text-slate-500 hover:text-slate-700'}`}>Digest</button>
                    <button onClick={() => setViewMode('source')} className={`px-4 py-1.5 text-[10px] font-bold uppercase tracking-widest transition-colors ${viewMode === 'source' ? 'bg-white dark:bg-slate-900 shadow-sm border border-slate-200 dark:border-slate-700 text-slate-900 dark:text-white' : 'text-slate-500 hover:text-slate-700'}`}>Source</button>
                  </div>
                  
                  <button onClick={() => handlePrint(false)} className="px-4 py-2 bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 text-slate-700 dark:text-slate-300 font-bold text-[10px] uppercase tracking-widest shadow-sm hover:bg-slate-200 dark:hover:bg-slate-700 transition-colors flex items-center mr-2">
                    <Printer className="w-3.5 h-3.5 mr-1" /> PDF
                  </button>

                  <button onClick={copyRichTextToDocs} className="px-5 py-2 bg-blue-600 text-white font-bold text-[10px] uppercase tracking-widest shadow-sm hover:bg-blue-700 transition-colors flex items-center">
                    {copiedSection === 'docs' ? <Check className="w-3.5 h-3.5 mr-1" /> : <Copy className="w-3.5 h-3.5 mr-1" />}
                    {copiedSection === 'docs' ? 'COPIED' : 'COPY DIGEST'}
                  </button>
                  
                  <div className="flex items-center border-l border-slate-300 dark:border-slate-700 pl-3 ml-3 space-x-1">
                    <button onClick={toggleMinimize} className="p-1.5 hover:bg-slate-100 dark:hover:bg-slate-800 text-slate-500 rounded transition-colors" title="Minimize">
                       <Minus className="w-4 h-4" />
                    </button>
                    <button onClick={() => setIsMaximized(!isMaximized)} className="p-1.5 hover:bg-slate-100 dark:hover:bg-slate-800 text-slate-500 rounded transition-colors" title={isMaximized ? "Restore Window" : "Maximize"}>
                      {isMaximized ? <Minimize className="w-4 h-4" /> : <Maximize className="w-4 h-4" />}
                    </button>
                    <button onClick={closeDigest} className="p-1.5 hover:bg-red-500 hover:text-white dark:hover:bg-red-900/30 text-slate-500 rounded transition-colors" title="Close">
                      <X className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              </div>

              <div 
                ref={contentAreaRef}
                onMouseUp={handleTextSelection} 
                className="flex-grow overflow-y-auto p-4 sm:p-8 custom-scrollbar relative bg-slate-50 dark:bg-slate-950 z-20 pointer-events-auto"
              >
                {highlighterPos && (
                  <div 
                    className="absolute bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 shadow-xl rounded-full px-3 py-2 flex items-center space-x-2 z-50 transform -translate-x-1/2 animate-in fade-in slide-in-from-bottom-2 pointer-events-auto"
                    style={{ top: highlighterPos.top, left: highlighterPos.left }}
                  >
                    <Highlighter className="w-3.5 h-3.5 text-slate-400 mr-1" />
                    <button onMouseDown={(e) => applyHighlight('hl-yellow', e)} className="w-5 h-5 rounded-full bg-yellow-200 border border-yellow-300 hover:scale-110 transition-transform"></button>
                    <button onMouseDown={(e) => applyHighlight('hl-green', e)} className="w-5 h-5 rounded-full bg-green-200 border border-green-300 hover:scale-110 transition-transform"></button>
                    <button onMouseDown={(e) => applyHighlight('hl-blue', e)} className="w-5 h-5 rounded-full bg-blue-200 border border-blue-300 hover:scale-110 transition-transform"></button>
                    <button onMouseDown={(e) => applyHighlight('hl-pink', e)} className="w-5 h-5 rounded-full bg-pink-200 border border-pink-300 hover:scale-110 transition-transform"></button>
                    <div className="w-px h-4 bg-slate-300 dark:bg-slate-600 mx-1"></div>
                    <button onMouseDown={removeHighlight} className="p-1 hover:bg-slate-100 dark:hover:bg-slate-700 rounded text-slate-500 transition-colors" title="Remove Highlight">
                      <Eraser className="w-4 h-4" />
                    </button>
                  </div>
                )}

                <div className={`mx-auto ${isMaximized ? 'max-w-5xl' : 'max-w-4xl'}`}>
                  <div className={`bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 p-10 shadow-sm ${viewMode === 'source' ? 'block' : 'hidden'}`}>
                    <h3 className="text-xs font-bold uppercase border-b border-slate-200 dark:border-slate-800 pb-4 mb-8 tracking-[0.2em] text-slate-500">Full Case Text Source</h3>
                    <div className="source-content whitespace-pre-wrap text-slate-800 dark:text-slate-200 leading-relaxed text-justify">
                      {currentDigest.extracted_source_text}
                    </div>
                  </div>
                  
                  <div className={`bg-white dark:bg-slate-900 border border-slate-300 dark:border-slate-800 shadow-sm overflow-hidden ${viewMode === 'digest' ? 'block' : 'hidden'}`}>
                    <table className="w-full text-left border-collapse digest-table">
                      <tbody className="divide-y divide-slate-200 dark:divide-slate-800 digest-content smart-text">
                        
                        <tr className="group">
                          <th className="w-[20%] p-6 bg-slate-50 dark:bg-slate-800/40 border-r align-top cursor-pointer hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors" onClick={() => toggleSection('parties')}>
                            <div className="flex justify-between items-center">
                              <span className="font-bold uppercase tracking-widest text-[7pt]">Parties</span>
                              {collapsedSections['parties'] ? <ChevronRight className="w-4 h-4 text-slate-400" /> : <ChevronDown className="w-4 h-4 text-slate-400" />}
                            </div>
                          </th>
                          <td className={`p-6 relative ${collapsedSections['parties'] ? 'hidden' : ''}`}>
                            <button onClick={() => copySectionPlain(`Petitioner: ${currentDigest.petitioner}\nRespondent: ${currentDigest.respondent}`, 'parties')} className="absolute top-6 right-6 text-slate-400 hover:text-blue-600 opacity-0 group-hover:opacity-100 bg-white p-1 rounded-full shadow-sm z-10 pointer-events-auto">{copiedSection === 'parties' ? <Check className="w-4 h-4 text-green-500" /> : <Copy className="w-4 h-4" />}</button>
                            <div className="pr-8"><strong>Petitioner:</strong> {currentDigest.petitioner}<br/><strong>Respondent:</strong> {currentDigest.respondent}</div>
                          </td>
                        </tr>
                        
                        <tr className="group">
                          <th className="w-[20%] p-6 bg-slate-50 dark:bg-slate-800/40 border-r align-top cursor-pointer hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors" onClick={() => toggleSection('facts')}>
                            <div className="flex justify-between items-center">
                              <span className="font-bold uppercase tracking-widest text-[7pt]">Facts</span>
                              {collapsedSections['facts'] ? <ChevronRight className="w-4 h-4 text-slate-400" /> : <ChevronDown className="w-4 h-4 text-slate-400" />}
                            </div>
                          </th>
                          <td className={`p-6 relative ${collapsedSections['facts'] ? 'hidden' : ''}`}>
                            <button onClick={() => copySectionPlain(currentDigest.facts, 'facts')} className="absolute top-6 right-6 text-slate-400 hover:text-blue-600 opacity-0 group-hover:opacity-100 bg-white p-1 rounded-full shadow-sm z-10 pointer-events-auto">{copiedSection === 'facts' ? <Check className="w-4 h-4 text-green-500" /> : <Copy className="w-4 h-4" />}</button>
                            <div dangerouslySetInnerHTML={parseText(currentDigest.facts)} className="pr-8" />
                            {currentDigest.ruling_lower_courts?.length > 0 && (
                               <div className="mt-6 border-t border-slate-100 dark:border-slate-800 pt-6">
                                <p className="text-[8px] font-bold uppercase tracking-widest text-slate-400 mb-3">Rulings of the Lower Courts</p>
                                {currentDigest.ruling_lower_courts.map((lc, idx) => (
                                  <div key={idx} className="mb-4 pl-4 border-l-2 border-slate-300 dark:border-slate-600"><p className="mb-1 text-xs"><strong>{lc.court}:</strong></p><div dangerouslySetInnerHTML={parseText(lc.ruling)} /></div>
                                ))}
                               </div>
                            )}
                          </td>
                        </tr>
                        
                        <tr className="group">
                          <th className="w-[20%] p-6 bg-slate-50 dark:bg-slate-800/40 border-r align-top cursor-pointer hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors" onClick={() => toggleSection('issues')}>
                            <div className="flex justify-between items-center">
                              <span className="font-bold uppercase tracking-widest text-[7pt]">Issue(s)</span>
                              {collapsedSections['issues'] ? <ChevronRight className="w-4 h-4 text-slate-400" /> : <ChevronDown className="w-4 h-4 text-slate-400" />}
                            </div>
                          </th>
                          <td className={`p-6 relative ${collapsedSections['issues'] ? 'hidden' : ''}`}>
                            <button onClick={() => copySectionPlain(currentDigest.issues?.join('\n'), 'issues')} className="absolute top-6 right-6 text-slate-400 hover:text-red-600 opacity-0 group-hover:opacity-100 bg-white p-1 rounded-full shadow-sm z-10 pointer-events-auto">{copiedSection === 'issues' ? <Check className="w-4 h-4 text-green-500" /> : <Copy className="w-4 h-4" />}</button>
                            <ol className="list-none space-y-4 pr-8">
                              {currentDigest.issues?.map((issue, idx) => (
                                <li key={idx} dangerouslySetInnerHTML={parseText(issue)} className="pl-0 text-[9pt]" />
                              ))}
                            </ol>
                          </td>
                        </tr>
                        
                        <tr className="group">
                          <th className="w-[20%] p-6 bg-slate-50 dark:bg-slate-800/40 border-r align-top cursor-pointer hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors" onClick={() => toggleSection('ruling')}>
                            <div className="flex justify-between items-center">
                              <span className="font-bold uppercase tracking-widest text-[7pt]">Ruling</span>
                              {collapsedSections['ruling'] ? <ChevronRight className="w-4 h-4 text-slate-400" /> : <ChevronDown className="w-4 h-4 text-slate-400" />}
                            </div>
                          </th>
                          <td className={`p-6 relative ${collapsedSections['ruling'] ? 'hidden' : ''}`}>
                            <button onClick={() => copySectionPlain('Ruling', 'ruling')} className="absolute top-6 right-6 text-slate-400 hover:text-green-600 opacity-0 group-hover:opacity-100 bg-white p-1 rounded-full shadow-sm z-10 pointer-events-auto">{copiedSection === 'ruling' ? <Check className="w-4 h-4 text-green-500" /> : <Copy className="w-4 h-4" />}</button>
                            <div className="space-y-6 pr-8">
                              {currentDigest.ruling_per_issue?.map((r, idx) => (
                                <div key={idx} className="p-5 border border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-800/50 rounded-sm">
                                  <strong className="block text-[7pt] text-slate-500 uppercase tracking-widest mb-2 border-b border-slate-200 dark:border-slate-700 pb-2">{r.issue_reference}</strong>
                                  <div dangerouslySetInnerHTML={parseText(r.ruling)} className="font-bold text-[9pt]" />
                                </div>
                              ))}
                            </div>
                          </td>
                        </tr>
                        
                        <tr className="group bg-blue-50/20 dark:bg-blue-900/10">
                          <th className="w-[20%] p-6 bg-blue-100/30 dark:bg-blue-900/30 border-r align-top cursor-pointer hover:bg-blue-100/50 dark:hover:bg-blue-900/50 transition-colors" onClick={() => toggleSection('ratio')}>
                            <div className="flex justify-between items-center">
                              <span className="font-bold uppercase tracking-widest text-[7pt] text-blue-900 dark:text-blue-200">Ratio</span>
                              {collapsedSections['ratio'] ? <ChevronRight className="w-4 h-4 text-blue-400" /> : <ChevronDown className="w-4 h-4 text-blue-400" />}
                            </div>
                          </th>
                          <td className={`p-6 relative ${collapsedSections['ratio'] ? 'hidden' : ''}`}>
                            <button onClick={() => copySectionPlain(JSON.stringify(currentDigest.ratio_per_issue), 'ratio')} className="absolute top-6 right-6 text-slate-400 hover:text-blue-600 opacity-0 group-hover:opacity-100 bg-white p-1 rounded-full shadow-sm z-10 pointer-events-auto">{copiedSection === 'ratio' ? <Check className="w-4 h-4 text-green-500" /> : <Copy className="w-4 h-4" />}</button>
                            <div className="space-y-8 pr-8">
                              {currentDigest.ratio_per_issue?.map((r, idx) => (
                                <div key={idx} className="relative">
                                  <strong className="block text-[7pt] text-blue-600 dark:text-blue-400 uppercase tracking-widest mb-3 flex items-center">
                                    <span className="w-1.5 h-1.5 bg-blue-500 rounded-full mr-2"></span>{r.issue_reference}
                                  </strong>
                                  <div className="pl-3.5 border-l border-blue-200 dark:border-blue-800">
                                    <div dangerouslySetInnerHTML={parseText(r.ratio)} className="space-y-4" />
                                  </div>
                                </div>
                              ))}
                            </div>
                          </td>
                        </tr>
                        
                        <tr className="group bg-red-50/20 dark:bg-red-900/10">
                          <th className="w-[20%] p-6 bg-red-100/30 dark:bg-red-900/30 border-r align-top cursor-pointer hover:bg-red-100/50 dark:hover:bg-red-900/50 transition-colors" onClick={() => toggleSection('dispositive')}>
                             <div className="flex justify-between items-center">
                               <span className="font-bold uppercase tracking-widest text-[7pt] text-red-900 dark:text-red-200">Dispositive</span>
                               {collapsedSections['dispositive'] ? <ChevronRight className="w-4 h-4 text-red-400" /> : <ChevronDown className="w-4 h-4 text-red-400" />}
                             </div>
                          </th>
                          <td className={`p-6 relative ${collapsedSections['dispositive'] ? 'hidden' : ''}`}>
                            <button onClick={() => copySectionPlain(currentDigest.dispositive_portion, 'disp')} className="absolute top-6 right-6 text-slate-400 hover:text-red-800 opacity-0 group-hover:opacity-100 bg-white p-1 rounded-full shadow-sm z-10 pointer-events-auto">{copiedSection === 'disp' ? <Check className="w-4 h-4 text-green-500" /> : <Copy className="w-4 h-4" />}</button>
                            <div className="font-serif italic text-[10pt] border-l-4 border-red-400 pl-4 py-2 bg-white dark:bg-slate-900 pr-8 shadow-sm">"{currentDigest.dispositive_portion}"</div>
                          </td>
                        </tr>
                        
                        <tr className="group">
                          <th className="w-[20%] p-6 bg-slate-50 dark:bg-slate-800/40 border-r align-top cursor-pointer hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors" onClick={() => toggleSection('doctrines')}>
                            <div className="flex justify-between items-center">
                              <span className="font-bold uppercase tracking-widest text-[7pt]">Doctrines</span>
                              {collapsedSections['doctrines'] ? <ChevronRight className="w-4 h-4 text-slate-400" /> : <ChevronDown className="w-4 h-4 text-slate-400" />}
                            </div>
                          </th>
                          <td className={`p-6 relative ${collapsedSections['doctrines'] ? 'hidden' : ''}`}>
                            <button onClick={() => copySectionPlain(currentDigest.doctrines?.join('\n'), 'doc')} className="absolute top-6 right-6 text-slate-400 hover:text-indigo-600 opacity-0 group-hover:opacity-100 bg-white p-1 rounded-full shadow-sm z-10 pointer-events-auto">{copiedSection === 'doc' ? <Check className="w-4 h-4 text-green-500" /> : <Copy className="w-4 h-4" />}</button>
                            <ul className="list-disc ml-5 space-y-4 pr-8">
                              {currentDigest.doctrines?.map((doc, idx) => <li key={idx} className="italic font-bold" dangerouslySetInnerHTML={parseText(doc)} />)}
                            </ul>
                          </td>
                        </tr>
                        
                        <tr className="group">
                          <th className="w-[20%] p-6 bg-slate-50 dark:bg-slate-800/40 border-r align-top cursor-pointer hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors" onClick={() => toggleSection('notes')}>
                            <div className="flex justify-between items-center">
                              <span className="font-bold uppercase tracking-widest text-[7pt]">Case Notes</span>
                              {collapsedSections['notes'] ? <ChevronRight className="w-4 h-4 text-slate-400" /> : <ChevronDown className="w-4 h-4 text-slate-400" />}
                            </div>
                          </th>
                          <td className={`p-6 bg-amber-50/10 dark:bg-amber-900/10 relative ${collapsedSections['notes'] ? 'hidden' : ''}`}>
                            <button onClick={() => copySectionPlain(currentDigest.case_notes?.join('\n'), 'notes')} className="absolute top-6 right-6 text-slate-400 hover:text-amber-600 opacity-0 group-hover:opacity-100 bg-white p-1 rounded-full shadow-sm z-10 pointer-events-auto">{copiedSection === 'notes' ? <Check className="w-4 h-4 text-green-500" /> : <Copy className="w-4 h-4" />}</button>
                            <ul className="list-disc ml-5 space-y-2 pr-8">
                              {currentDigest.case_notes?.map((note, idx) => <li key={idx} dangerouslySetInnerHTML={parseText(note)} />)}
                            </ul>
                          </td>
                        </tr>

                        <tr className="group border-t-4 border-slate-300 dark:border-slate-800">
                          <th className="w-[20%] p-6 bg-emerald-50 dark:bg-emerald-900/20 border-r align-top cursor-pointer hover:bg-emerald-100/50 dark:hover:bg-emerald-900/40 transition-colors" onClick={() => toggleSection('pnotes')}>
                            <div className="flex flex-col">
                              <div className="flex justify-between items-start">
                                <span className="flex items-center text-[7pt] font-bold uppercase tracking-widest text-emerald-800 dark:text-emerald-400"><PenTool className="w-3.5 h-3.5 mr-1" />Personal Notes</span>
                                {collapsedSections['pnotes'] ? <ChevronRight className="w-4 h-4 text-emerald-600" /> : <ChevronDown className="w-4 h-4 text-emerald-600" />}
                              </div>
                              <button 
                                onClick={(e) => { e.stopPropagation(); handleDraftRecitScript(); }} 
                                disabled={isDraftingRecit} 
                                className="mt-4 px-2 py-1.5 bg-emerald-100 hover:bg-emerald-200 dark:bg-emerald-800 dark:hover:bg-emerald-700 text-emerald-700 dark:text-emerald-300 text-[8px] font-bold rounded uppercase tracking-widest transition-colors flex items-center justify-center w-full shadow-sm pointer-events-auto"
                              >
                                {isDraftingRecit ? <><Loader2 className="w-3 h-3 mr-1 animate-spin" /> Drafting...</> : <><Sparkles className="w-3 h-3 mr-1" /> Draft Recit Script</>}
                              </button>
                            </div>
                          </th>
                          <td className={`p-6 bg-emerald-50/20 dark:bg-emerald-900/10 relative ${collapsedSections['pnotes'] ? 'hidden' : ''}`}>
                            <button onClick={() => copySectionPlain(currentDigest.personal_notes, 'pnotes')} className="absolute top-6 right-6 text-emerald-600 hover:text-emerald-800 opacity-0 group-hover:opacity-100 bg-white p-1 rounded-full shadow-sm z-10 pointer-events-auto">{copiedSection === 'pnotes' ? <Check className="w-4 h-4 text-green-500" /> : <Copy className="w-4 h-4" />}</button>
                            <textarea 
                              className="w-full h-40 p-5 text-sm bg-white dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded-sm focus:outline-none focus:border-emerald-500 custom-scrollbar resize-y text-slate-800 dark:text-slate-200 shadow-inner leading-relaxed pointer-events-auto"
                              placeholder="Type your personal notes, mnemonics, or class recitations here... (Auto-saves to history)"
                              value={currentDigest.personal_notes || ''}
                              onChange={(e) => handleUpdateNotes(e.target.value)}
                            />
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* MINIMIZED FLOATING TABS */}
        {isMinimized && (
          <div className="fixed bottom-6 left-6 z-[60] flex flex-col space-y-3 pointer-events-auto">
            {currentDigest && !isCollectiveMode && (
              <div className="w-80 bg-white dark:bg-slate-800 rounded-xl shadow-[0_10px_40px_rgba(0,0,0,0.2)] border border-slate-200 dark:border-slate-700 flex items-center p-4 cursor-pointer hover:scale-105 transition-transform" onClick={() => setIsMinimized(false)}>
                 <BookOpen className="w-6 h-6 text-blue-600 mr-3 flex-shrink-0" />
                 <div className="flex-grow min-w-0">
                   <h4 className="text-sm font-bold text-slate-900 dark:text-white truncate">{currentDigest.title}</h4>
                   <p className="text-[10px] text-slate-500 uppercase tracking-widest truncate">Click to restore</p>
                 </div>
                 <button onClick={(e) => { e.stopPropagation(); closeDigest(); }} className="ml-2 p-1.5 hover:bg-red-100 dark:hover:bg-red-900/30 text-slate-400 hover:text-red-600 rounded transition-colors">
                   <X className="w-4 h-4" />
                 </button>
              </div>
            )}
            
            {isCollectiveMode && (
              <div className="w-80 bg-white dark:bg-slate-800 rounded-xl shadow-[0_10px_40px_rgba(0,0,0,0.2)] border border-slate-200 dark:border-slate-700 flex items-center p-4 cursor-pointer hover:scale-105 transition-transform" onClick={() => setIsMinimized(false)}>
                 <Layers className="w-6 h-6 text-blue-600 mr-3 flex-shrink-0" />
                 <div className="flex-grow min-w-0">
                   <h4 className="text-sm font-bold text-slate-900 dark:text-white truncate">Collective Digest</h4>
                   <p className="text-[10px] text-slate-500 uppercase tracking-widest truncate">{selectedCaseIds.length} Cases • Click to restore</p>
                 </div>
                 <button onClick={(e) => { e.stopPropagation(); closeCollectiveView(); }} className="ml-2 p-1.5 hover:bg-red-100 dark:hover:bg-red-900/30 text-slate-400 hover:text-red-600 rounded transition-colors">
                   <X className="w-4 h-4" />
                 </button>
              </div>
            )}
          </div>
        )}

      </main>

      {/* Dean Sabio Chat */}
      <div className="fixed bottom-6 right-6 z-[80] flex flex-col items-end pointer-events-none">
        <div className={`transition-all duration-300 transform origin-bottom-right mb-4 pointer-events-auto ${isChatOpen ? 'scale-100 opacity-100' : 'scale-90 opacity-0 pointer-events-none'}`} style={{ width: '380px', height: '540px' }}>
          <div className="bg-white dark:bg-slate-900 border border-slate-300 dark:border-slate-800 shadow-2xl flex flex-col h-full rounded-sm overflow-hidden">
            <div className="bg-slate-900 text-white p-4 flex justify-between items-center border-b border-slate-800">
              <div className="flex items-center"><Bot className="w-4 h-4 mr-2 text-blue-400" /><span className="text-[10px] font-bold uppercase tracking-widest">Dean Sabio</span></div>
              <button onClick={() => setIsChatOpen(false)}><X className="w-4 h-4 text-slate-400 hover:text-white" /></button>
            </div>
            
            <div className="flex-grow p-5 overflow-y-auto space-y-5 bg-slate-50 dark:bg-slate-950 custom-scrollbar pointer-events-auto">
              {chatMessages.map((msg, i) => (
                <div key={i} className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}>
                  <div className={`max-w-[85%] p-3 text-[11px] leading-relaxed shadow-sm ${msg.role === 'user' ? 'bg-blue-600 text-white' : 'bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700'}`}>
                    <span dangerouslySetInnerHTML={parseText(msg.text)} />
                  </div>
                </div>
              ))}
              {isChatLoading && <div className="text-[9px] italic text-slate-400 font-mono">Dean Sabio is reviewing the jurisprudence...</div>}
              <div ref={chatMessagesEndRef} />
            </div>

            <div className="p-3 border-t border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 flex flex-col gap-3 pointer-events-auto">
              {currentDigest && (
                <div className="flex gap-2 overflow-x-auto custom-scrollbar pb-1">
                  <button onClick={() => handleChatSend("✨ Please quiz me on this case. Ask a tough Socratic question.")} className="whitespace-nowrap px-3 py-1.5 bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 text-[9px] rounded-full hover:bg-blue-100 hover:text-blue-600 transition-colors border border-slate-200 dark:border-slate-700 flex items-center font-bold tracking-wide shadow-sm"><Sparkles className="w-3 h-3 mr-1" /> Quiz Me</button>
                  <button onClick={() => handleChatSend("✨ Explain the main doctrine of this case to me like I am a 5-year-old.")} className="whitespace-nowrap px-3 py-1.5 bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 text-[9px] rounded-full hover:bg-blue-100 hover:text-blue-600 transition-colors border border-slate-200 dark:border-slate-700 flex items-center font-bold tracking-wide shadow-sm"><Sparkles className="w-3 h-3 mr-1" /> Explain Like I'm 5</button>
                  <button onClick={() => handleChatSend("✨ What are the possible counter-arguments or dissenting views against this ruling?")} className="whitespace-nowrap px-3 py-1.5 bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 text-[9px] rounded-full hover:bg-blue-100 hover:text-blue-600 transition-colors border border-slate-200 dark:border-slate-700 flex items-center font-bold tracking-wide shadow-sm"><Sparkles className="w-3 h-3 mr-1" /> Counter-Arguments</button>
                </div>
              )}
              <div className="flex">
                <input type="text" value={chatInput} onChange={e => setChatInput(e.target.value)} onKeyDown={e => e.key === 'Enter' && handleChatSend()} placeholder="Ask Counselor Sabio..." className="flex-grow px-3 py-2 text-[11px] border border-slate-300 dark:border-slate-700 focus:outline-none focus:border-blue-500 dark:bg-slate-800" />
                <button onClick={() => handleChatSend()} className="px-4 bg-blue-600 text-white hover:bg-blue-700 transition-colors"><Send className="w-3.5 h-3.5" /></button>
              </div>
            </div>
          </div>
        </div>
        <button onClick={() => setIsChatOpen(!isChatOpen)} className={`p-4 rounded-full shadow-2xl transition-all pointer-events-auto ${isChatOpen ? 'bg-slate-900 border border-slate-700' : 'bg-blue-600'} text-white flex items-center justify-center hover:scale-110 active:scale-95`}>
          {isChatOpen ? <X className="w-6 h-6" /> : <MessageCircle className="w-6 h-6" />}
        </button>
      </div>
    </div>
  );
}
