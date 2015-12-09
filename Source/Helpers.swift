//
//  Copyright (c) 2015 Algolia
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

import UIKit

extension UILabel {
    var highlightedText: String? {
        get {
            return attributedText?.string
        }
        set {
            attributedTextFromHtml(newValue)
        }
    }
    
    private func attributedTextFromHtml(htmlText: String?) {
        if htmlText == nil {
            attributedText = nil
        }
        else {
            let text = NSMutableString(string: htmlText!)
            let rangesOfAttributes = getRangeToHighlight(text)
            let attributedString = NSMutableAttributedString(string: String(text))
            for range in rangesOfAttributes {
                let color = highlightedTextColor ?? UIColor.yellowColor()
                attributedString.addAttribute(NSBackgroundColorAttributeName, value: color, range: range)
            }
            attributedText = attributedString
        }
    }
    
    private func getRangeToHighlight(text: NSMutableString) -> [NSRange] {
        var rangesOfAttributes = [NSRange]()
        
        while true {
            let matchBegin = text.rangeOfString("<em>", options: .CaseInsensitiveSearch)
            
            if matchBegin.location != NSNotFound {
                text.deleteCharactersInRange(matchBegin)
                let firstCharacter = matchBegin.location
                
                let range = NSRange(location: firstCharacter, length: text.length - firstCharacter)
                let matchEnd = text.rangeOfString("</em>", options: .CaseInsensitiveSearch, range: range)
                if matchEnd.location != NSNotFound {
                    text.deleteCharactersInRange(matchEnd)
                    let lastCharacter = matchEnd.location
                    
                    rangesOfAttributes.append(NSRange(location: firstCharacter, length: lastCharacter - firstCharacter))
                }
            } else {
                break
            }
        }
        
        return rangesOfAttributes
    }
}
