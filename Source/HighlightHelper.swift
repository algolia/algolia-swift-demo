//
//  Copyright (c) 2016 Algolia
//  http://www.algolia.com/
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation


/// Renders marked up text into attributed strings with markup removed and the visual attributes applied to highlights.
///
public class HighlightRenderer {
    /// Visual attributes to apply to the highlights.
    var highlightAttrs: [String: AnyObject]
    
    /// Markup identifying the beginning of a highlight. Defaults to "<em>".
    var startTag: String = "<em>"

    /// Markup identifying the end of a highlight. Defaults to "</em>".
    var endTag: String = "</em>"

    /// Whether the markup is case sensitive. Defaults to false.
    var caseSensitive: Bool = false
    
    public init(highlightAttrs: [String: AnyObject]) {
        self.highlightAttrs = highlightAttrs
    }

    /// Render the specified text.
    ///
    /// - param text: The marked up text to render.
    /// - return: An atributed string with highlights outlined.
    ///
    public func render(text: String) -> NSAttributedString {
        let newText = NSMutableString(string: text)
        var rangesToHighlight = [NSRange]()
        
        // Remove markup and identify ranges to highlight at the same time.
        while true {
            let matchBegin = newText.rangeOfString(startTag, options: caseSensitive ? [] : [.CaseInsensitiveSearch])
            if matchBegin.location != NSNotFound {
                newText.deleteCharactersInRange(matchBegin)
                let range = NSRange(location: matchBegin.location, length: newText.length - matchBegin.location)
                let matchEnd = newText.rangeOfString(endTag, options: .CaseInsensitiveSearch, range: range)
                if matchEnd.location != NSNotFound {
                    newText.deleteCharactersInRange(matchEnd)
                    rangesToHighlight.append(NSRange(location: matchBegin.location, length: matchEnd.location - matchBegin.location))
                }
            } else {
                break
            }
        }
        
        // Apply the specified attributes to the highlighted ranges.
        let attributedString = NSMutableAttributedString(string: String(newText))
        for range in rangesToHighlight {
            attributedString.addAttributes(highlightAttrs, range: range)
        }
        return attributedString
    }
}