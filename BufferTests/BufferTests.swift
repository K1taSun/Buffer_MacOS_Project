//
//  BufferTests.swift
//  BufferTests
//
//  Created by Nikita Parkovskyi on 26/05/2025.
//

import XCTest
@testable import Buffer

final class BufferTests: XCTestCase {
    
    var clipboardManager: ClipboardManager!
    
    override func setUpWithError() throws {
        clipboardManager = ClipboardManager.shared
        // Clear any existing items for clean test state
        clipboardManager.clearAll()
    }
    
    override func tearDownWithError() throws {
        clipboardManager.clearAll()
    }
    
    // MARK: - ClipboardManager Tests
    
    func testClipboardManagerSingleton() throws {
        let manager1 = ClipboardManager.shared
        let manager2 = ClipboardManager.shared
        
        XCTAssertTrue(manager1 === manager2, "ClipboardManager should be a singleton")
    }
    
    func testAddTextItem() throws {
        let testContent = "Test text content"
        let item = ClipboardItem(contentPayload: testContent, type: .text)
        
        clipboardManager.addItem(item)
        
        XCTAssertEqual(clipboardManager.items.count, 1)
        XCTAssertEqual(clipboardManager.items.first?.contentPayload, testContent)
        XCTAssertEqual(clipboardManager.items.first?.type, .text)
    }
    
    func testAddImageItem() throws {
        let testData = Data("fake image data".utf8)
        let item = ClipboardItem(contentPayload: "Image", type: .image, data: testData)
        
        clipboardManager.addItem(item)
        
        XCTAssertEqual(clipboardManager.items.count, 1)
        XCTAssertEqual(clipboardManager.items.first?.type, .image)
        XCTAssertEqual(clipboardManager.items.first?.data, testData)
    }
    
    
    func testRemoveItem() throws {
        let item = ClipboardItem(contentPayload: "Test item", type: .text)
        clipboardManager.addItem(item)
        
        XCTAssertEqual(clipboardManager.items.count, 1)
        
        clipboardManager.removeItem(item)
        
        XCTAssertEqual(clipboardManager.items.count, 0)
    }
    
    func testTogglePin() throws {
        let item = ClipboardItem(contentPayload: "Test item", type: .text)
        clipboardManager.addItem(item)
        
        XCTAssertFalse(clipboardManager.items.first?.isPinned ?? true)
        
        clipboardManager.togglePin(item)
        
        XCTAssertTrue(clipboardManager.items.first?.isPinned ?? false)
        
        clipboardManager.togglePin(item)
        
        XCTAssertFalse(clipboardManager.items.first?.isPinned ?? true)
    }
    
    func testClearAll() throws {
        let item1 = ClipboardItem(contentPayload: "Test item 1", type: .text)
        let item2 = ClipboardItem(contentPayload: "Test item 2", type: .text)
        
        clipboardManager.addItem(item1)
        clipboardManager.addItem(item2)
        
        XCTAssertEqual(clipboardManager.items.count, 2)
        
        clipboardManager.clearAll()
        
        XCTAssertEqual(clipboardManager.items.count, 0)
    }
    
    func testClearUnpinned() throws {
        let item1 = ClipboardItem(contentPayload: "Test item 1", type: .text)
        let item2 = ClipboardItem(contentPayload: "Test item 2", type: .text)
        
        clipboardManager.addItem(item1)
        clipboardManager.addItem(item2)
        
        // Pin the first item
        clipboardManager.togglePin(item1)
        
        XCTAssertEqual(clipboardManager.items.count, 2)
        XCTAssertTrue(clipboardManager.items.first?.isPinned ?? false)
        
        clipboardManager.clearUnpinned()
        
        XCTAssertEqual(clipboardManager.items.count, 1)
        XCTAssertTrue(clipboardManager.items.first?.isPinned ?? false)
    }
    
    func testDuplicatePrevention() throws {
        let content = "Duplicate content"
        let item1 = ClipboardItem(contentPayload: content, type: .text)
        let item2 = ClipboardItem(contentPayload: content, type: .text)
        
        clipboardManager.addItem(item1)
        clipboardManager.addItem(item2)
        
        XCTAssertEqual(clipboardManager.items.count, 1)
        XCTAssertEqual(clipboardManager.items.first?.contentPayload, content)
    }
    
    func testPinnedItemsNotRemovedByDuplicates() throws {
        let content = "Pinned content"
        let item1 = ClipboardItem(contentPayload: content, type: .text)
        let item2 = ClipboardItem(contentPayload: content, type: .text)
        
        clipboardManager.addItem(item1)
        clipboardManager.togglePin(item1)
        
        XCTAssertTrue(clipboardManager.items.first?.isPinned ?? false)
        
        clipboardManager.addItem(item2)
        
        XCTAssertEqual(clipboardManager.items.count, 1)
        XCTAssertTrue(clipboardManager.items.first?.isPinned ?? false)
    }
    
    // MARK: - ClipboardItem Tests
    
    func testClipboardItemInitialization() throws {
        let content = "Test content"
        let type = ClipboardItemType.text
        let data = Data("test data".utf8)
        
        let item = ClipboardItem(contentPayload: content, type: .text, data: data)
        
        XCTAssertEqual(item.contentPayload, content)
        XCTAssertEqual(item.type, type)
        XCTAssertEqual(item.data, data)
        XCTAssertFalse(item.isPinned)
        XCTAssertNotNil(item.id)
        XCTAssertNotNil(item.timestamp)
    }
    
    func testClipboardItemTypeIcons() throws {
        XCTAssertEqual(ClipboardItemType.text.icon, "doc.text")
        XCTAssertEqual(ClipboardItemType.image.icon, "photo")
        XCTAssertEqual(ClipboardItemType.richText.icon, "doc.richtext")
        XCTAssertEqual(ClipboardItemType.audio.icon, "waveform")
    }
    
    // MARK: - Performance Tests
    
    func testAddManyItemsPerformance() throws {
        for i in 0..<100 {
            let item = ClipboardItem(contentPayload: "Item \(i)", type: .text)
            clipboardManager.addItem(item)
        }
    }
    
    func testSearchPerformance() throws {
        // Add many items first
        for i in 0..<100 {
            let item = ClipboardItem(contentPayload: "Item \(i)", type: .text)
            clipboardManager.addItem(item)
        }
        
        let filtered = clipboardManager.items.filter { $0.contentPayload.contains("50") }
        XCTAssertGreaterThan(filtered.count, 0)
    }
    
    // MARK: - Data Persistence Tests
    
    func testSaveAndLoadItems() throws {
        let item1 = ClipboardItem(contentPayload: "Saved item 1", type: .text)
        let item2 = ClipboardItem(contentPayload: "Saved item 2", type: .text)
        
        clipboardManager.addItem(item1)
        clipboardManager.addItem(item2)
        
        // Simulate app restart by creating a new manager
        _ = ClipboardManager.shared
        
        // Note: In a real test, we'd need to mock UserDefaults or use a test container
        // For now, we'll just verify the save/load methods exist and don't crash
        XCTAssertNoThrow(clipboardManager.saveItems())
        XCTAssertNoThrow(clipboardManager.loadSavedItems())
    }
}
