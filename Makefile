.PHONY: test test-performance test-determinism test-validation test-all clean

# run all tests
test:
	@echo "========================================="
	@echo "running all test suites..."
	@echo "========================================="
	@echo ""
	@echo "[1/9] Structure tests..."
	@START=$$(date +%s); bash test/test_structure.sh; END=$$(date +%s); echo "duration: $$((END - START))s"
	@echo ""
	@echo "[2/9] Input validation tests..."
	@START=$$(date +%s); bash test/test_input_validation.sh; END=$$(date +%s); echo "duration: $$((END - START))s"
	@echo ""
	@echo "[3/9] Input parsing tests..."
	@START=$$(date +%s); bash test/test_input_parsing.sh; END=$$(date +%s); echo "duration: $$((END - START))s"
	@echo ""
	@echo "[4/9] Component validation tests..."
	@START=$$(date +%s); bash test/test_component_validation.sh; END=$$(date +%s); echo "duration: $$((END - START))s"
	@echo ""
	@echo "[5/9] Calendar conversion tests..."
	@START=$$(date +%s); bash test/test_calendar_conversion.sh; END=$$(date +%s); echo "duration: $$((END - START))s"
	@echo ""
	@echo "[6/9] Date normalization tests..."
	@START=$$(date +%s); bash test/test_date_normalization.sh; END=$$(date +%s); echo "duration: $$((END - START))s"
	@echo ""
	@echo "[7/9] Time normalization tests..."
	@START=$$(date +%s); bash test/test_time_normalization.sh; END=$$(date +%s); echo "duration: $$((END - START))s"
	@echo ""
	@echo "[8/9] Timezone rollover tests..."
	@START=$$(date +%s); bash test/test_timezone_rollover.sh; END=$$(date +%s); echo "duration: $$((END - START))s"
	@echo ""
	@echo "[9/9] Timezone parsing tests..."
	@START=$$(date +%s); bash test/test_timezone_parsing.sh; END=$$(date +%s); echo "duration: $$((END - START))s"
	@echo ""
	@echo "========================================="
	@echo "all test suites completed!"
	@echo "========================================="

# run performance tests
test-performance:
	@bash test/test_performance.sh

# run determinism tests
test-determinism:
	@bash test/test_determinism.sh

# run final validation tests
test-validation:
	@bash test/test_final_validation.sh

# run all tests including performance and validation
test-all: test test-performance test-determinism test-validation
	@echo ""
	@echo "========================================="
	@echo "all tests completed successfully!"
	@echo "========================================="

clean:
	@echo "cleaning up temporary files..."
	@rm -f test/*.tmp
	@echo "done."
