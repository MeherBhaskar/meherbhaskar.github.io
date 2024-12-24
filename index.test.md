import unittest
from bs4 import BeautifulSoup
import markdown
import re

class TestIndexMd(unittest.TestCase):
    def setUp(self):
        with open('index.md', 'r') as file:
            content = file.read()
        html = markdown.markdown(content)
        self.soup = BeautifulSoup(html, 'html.parser')

if __name__ == '__main__':
    unittest.main()
    
def test_header_sections():
    with open('index.md', 'r') as file:
        content = file.read()
    
    assert '## 👤 About Me' in content, "About Me section is missing"
    assert '## 🛠️ Technical Experience' in content, "Technical Experience section is missing"
    assert '## 🎓 Education' in content, "Education section is missing"
    assert '##  🛠️ Skills' in content, "Skills section is missing"